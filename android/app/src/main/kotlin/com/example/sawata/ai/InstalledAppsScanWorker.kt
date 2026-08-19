package com.example.sawata.ai

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.tasks.await

/**
 * Enqueues an [AppClassificationWorker] for currently-installed launchable
 * apps not already known — triggered by SawataAccessibilityService the
 * moment it observes protectionActive flip false -> true.
 *
 * Two safeguards specific to a full-device scan (as opposed to a single
 * ACTION_PACKAGE_ADDED event):
 *  - System apps (and system apps later updated via Play Store — Chrome,
 *    Gmail, Play Store itself, etc.) are filtered out before anything is
 *    enqueued: they're OEM-bundled, not something a user "installed" in the
 *    sense this feature cares about, and burning a Gemini call on
 *    Settings/Camera/Phone on every single device is pure waste.
 *  - Already-known packages (globally blocked, personally blocked, or a
 *    still-fresh cached AI result) are filtered out via three whole-collection
 *    reads up front, not a per-package round trip. AppClassificationWorker
 *    still re-checks all of this itself right before calling Gemini — that
 *    stays as the authoritative, race-safe check; this is purely to avoid
 *    registering hundreds of WorkManager jobs that would immediately no-op.
 *  - The remaining candidates are dispatched in small chunks
 *    (AiConfig.MAX_CONCURRENT_APP_CLASSIFICATIONS), awaiting each chunk's
 *    jobs to reach a terminal state before enqueueing the next — so a
 *    first-time Protection activation on a device with 200 apps never has
 *    more than a handful of Gemini calls in flight at once.
 */
class InstalledAppsScanWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val queuedUid = inputData.getString(KEY_UID) ?: return Result.success()
        val currentUid = FirebaseAuth.getInstance().currentUser?.uid
        if (currentUid == null || currentUid != queuedUid) {
            Log.i(TAG, "Skip scan — uid mismatch (queued=$queuedUid current=$currentUid)")
            return Result.success()
        }

        val firestore = FirebaseFirestore.getInstance()
        val userDoc = firestore.collection("users").document(currentUid).get().await()
        if (userDoc.getBoolean("protectionActive") != true) {
            Log.i(TAG, "Skip scan — protection is off")
            return Result.success()
        }

        val pm = applicationContext.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
        val ownPackage = applicationContext.packageName
        val launchablePackages = pm.queryIntentActivities(launcherIntent, 0)
            .asSequence()
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != ownPackage }
            .filterNot { (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0 }
            .map { it.packageName }
            .toList()

        if (launchablePackages.isEmpty()) {
            Log.i(TAG, "Installed-apps scan: no non-system launchable apps for uid=$currentUid")
            return Result.success()
        }

        val globallyBlocked = firestore.collection("blocked_packages").get().await()
            .documents.map { it.id }.toSet()

        val personallyBlocked = firestore.collection("users").document(currentUid)
            .collection("blocked_items")
            .whereEqualTo("category", "App")
            .get().await()
            .documents.mapNotNull { it.getString("packageName") }.toSet()

        val freshlyCached = firestore.collection("users").document(currentUid)
            .collection("ai_app_detections")
            .get().await()
            .documents.filter { DetectionCache.isFresh(it) }.map { it.id }.toSet()

        val toClassify = launchablePackages.filterNot {
            it in globallyBlocked || it in personallyBlocked || it in freshlyCached
        }

        Log.i(
            TAG,
            "Installed-apps scan: ${launchablePackages.size} non-system launchable, " +
                "${toClassify.size} need classification (uid=$currentUid)",
        )
        if (toClassify.isEmpty()) return Result.success()

        val workManager = WorkManager.getInstance(applicationContext)
        for (chunk in toClassify.chunked(AiConfig.MAX_CONCURRENT_APP_CLASSIFICATIONS)) {
            Log.i(TAG, "Dispatching classification chunk: $chunk")
            for (packageName in chunk) {
                AppClassificationWorker.enqueue(applicationContext, currentUid, packageName)
            }
            // Gate on this chunk finishing before the next one is enqueued —
            // this is what actually bounds concurrent Gemini calls to
            // AiConfig.MAX_CONCURRENT_APP_CLASSIFICATIONS, rather than
            // relying on WorkManager's own (larger, shared-with-everything)
            // executor pool size.
            for (packageName in chunk) {
                val name = AppClassificationWorker.uniqueWorkName(currentUid, packageName)
                workManager.getWorkInfosForUniqueWorkFlow(name)
                    .first { infos -> infos.isEmpty() || infos.all { it.state.isFinished } }
            }
        }

        return Result.success()
    }

    companion object {
        private const val TAG = "SawataInstalledAppsScan"
        private const val KEY_UID = "uid"

        fun enqueue(context: Context, uid: String) {
            val data = workDataOf(KEY_UID to uid)
            val request = OneTimeWorkRequestBuilder<InstalledAppsScanWorker>()
                .setInputData(data)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                "ai-scan-installed-apps-$uid",
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }
}
