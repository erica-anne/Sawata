package com.example.sawata.ai

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkRequest
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import java.util.Date
import java.util.concurrent.TimeUnit

/**
 * Classifies one app for one user via [GeminiClassifier] and writes the
 * result under users/{uid}/ai_app_detections. Every safeguard here is
 * deliberate:
 *  - uid is bound at enqueue time and re-checked at run time (a pending job
 *    from a signed-out/switched account must never write under the new
 *    account).
 *  - protectionActive is re-checked immediately before the Gemini call, not
 *    just at enqueue time — if the user turned Protection off in between,
 *    this no-ops; the next Protection-ON scan (see
 *    SawataAccessibilityService) will rediscover the app.
 *  - already-blocked (global or personal) apps are skipped outright — no
 *    point spending a Gemini call on something already enforced.
 *  - a fresh cached result (see DetectionCache) is never reclassified,
 *    except when this run is an app UPDATE and the cached verdict wasn't
 *    already "gambling" — see AppInstallReceiver.
 */
class AppClassificationWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val queuedUid = inputData.getString(KEY_UID) ?: return Result.success()
        val packageName = inputData.getString(KEY_PACKAGE) ?: return Result.success()
        val isUpdate = inputData.getBoolean(KEY_IS_UPDATE, false)

        val currentUid = FirebaseAuth.getInstance().currentUser?.uid
        if (currentUid == null || currentUid != queuedUid) {
            Log.i(TAG, "Skip $packageName — uid mismatch (queued=$queuedUid current=$currentUid)")
            return Result.success()
        }

        val firestore = FirebaseFirestore.getInstance()
        val userDoc = firestore.collection("users").document(currentUid).get().await()
        if (userDoc.getBoolean("protectionActive") != true) {
            Log.i(TAG, "Skip $packageName — protection is off")
            return Result.success()
        }

        if (firestore.collection("blocked_packages").document(packageName).get().await().exists()) {
            Log.i(TAG, "Skip $packageName — already globally blocked")
            return Result.success()
        }

        val personalMatch = firestore.collection("users").document(currentUid)
            .collection("blocked_items")
            .whereEqualTo("packageName", packageName)
            .limit(1).get().await()
        if (!personalMatch.isEmpty) {
            Log.i(TAG, "Skip $packageName — already personally blocked")
            return Result.success()
        }

        val detectionRef = firestore.collection("users").document(currentUid)
            .collection("ai_app_detections").document(packageName)
        val existing = detectionRef.get().await()
        val shouldClassify = !existing.exists() ||
            !DetectionCache.isFresh(existing) ||
            (isUpdate && existing.getString("classification") != "gambling")
        if (!shouldClassify) {
            Log.i(TAG, "Skip $packageName — cached AI result still fresh")
            return Result.success()
        }

        val appName = resolveAppName(packageName)
        Log.i(TAG, "Classifying app pkg=$packageName name=\"$appName\" uid=$currentUid isUpdate=$isUpdate")

        val result = GeminiClassifier.classifyApp(appName, packageName)
        if (result == null) {
            return if (runAttemptCount < AiConfig.MAX_RETRIES) Result.retry() else Result.failure()
        }
        Log.i(TAG, "Writing ai_app_detections/$packageName -> ${result.classification} (${result.confidence})")

        detectionRef.set(
            mapOf(
                "name" to appName,
                "classification" to result.classification,
                "confidence" to result.confidence,
                "reason" to result.reason,
                "model" to GeminiClassifier.MODEL_NAME,
                "classifierVersion" to GeminiClassifier.CLASSIFIER_VERSION,
                "classifiedAt" to Date(),
            ),
        ).await()

        if (result.classification == "gambling") {
            firestore.collection("ai_candidates").add(
                mapOf(
                    "type" to "app",
                    "key" to packageName,
                    "name" to appName,
                    "classification" to result.classification,
                    "confidence" to result.confidence,
                    "reason" to result.reason,
                    "reportedByUid" to currentUid,
                    "model" to GeminiClassifier.MODEL_NAME,
                    "classifierVersion" to GeminiClassifier.CLASSIFIER_VERSION,
                    "detectedAt" to Date(),
                ),
            ).await()

            if (result.confidence < AiConfig.HIGH_CONFIDENCE_THRESHOLD) {
                Log.i(TAG, "Medium-confidence gambling — writing suggestion for $packageName")
                firestore.collection("users").document(currentUid)
                    .collection("suggestions").document(packageName)
                    .set(
                        mapOf(
                            "name" to appName,
                            "packageName" to packageName,
                            "status" to "pending",
                            "suggestedAt" to Date(),
                        ),
                    ).await()
            } else {
                Log.i(TAG, "High-confidence gambling — $packageName enters the effective block set")
            }
        }

        return Result.success()
    }

    private fun resolveAppName(packageName: String): String = try {
        val pm = applicationContext.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (e: PackageManager.NameNotFoundException) {
        packageName
    }

    companion object {
        private const val TAG = "SawataAppClassifyWorker"
        private const val KEY_UID = "uid"
        private const val KEY_PACKAGE = "packageName"
        private const val KEY_IS_UPDATE = "isUpdate"

        /** Exposed so InstalledAppsScanWorker can await this exact job's completion. */
        fun uniqueWorkName(uid: String, packageName: String) = "ai-classify-app-$uid-$packageName"

        fun enqueue(context: Context, uid: String, packageName: String, isUpdate: Boolean = false) {
            val data = workDataOf(
                KEY_UID to uid,
                KEY_PACKAGE to packageName,
                KEY_IS_UPDATE to isUpdate,
            )
            val request = OneTimeWorkRequestBuilder<AppClassificationWorker>()
                .setInputData(data)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, WorkRequest.MIN_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                uniqueWorkName(uid, packageName),
                ExistingWorkPolicy.KEEP,
                request,
            )
        }
    }
}
