package com.example.sawata.ai

import android.content.Context
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
 * Domain counterpart to [AppClassificationWorker] — same uid-binding,
 * protectionActive re-check, and freshness-cache safeguards. Never invoked
 * from UdpRelay's packet-handling thread directly; see
 * DomainBlocklist.maybeQueueForClassification for the prefilter/dedup/rate
 * limit that decides whether a domain gets enqueued at all. No suggestion
 * path for medium-confidence domains in this pass — cache only.
 */
class DomainClassificationWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val queuedUid = inputData.getString(KEY_UID) ?: return Result.success()
        val domain = inputData.getString(KEY_DOMAIN) ?: return Result.success()

        val currentUid = FirebaseAuth.getInstance().currentUser?.uid
        if (currentUid == null || currentUid != queuedUid) {
            Log.i(TAG, "Skip $domain — uid mismatch (queued=$queuedUid current=$currentUid)")
            return Result.success()
        }

        val firestore = FirebaseFirestore.getInstance()
        val userDoc = firestore.collection("users").document(currentUid).get().await()
        if (userDoc.getBoolean("protectionActive") != true) {
            Log.i(TAG, "Skip $domain — protection is off")
            return Result.success()
        }

        if (firestore.collection("blocked_domains").document(domain).get().await().exists()) {
            Log.i(TAG, "Skip $domain — already globally blocked")
            return Result.success()
        }

        val detectionRef = firestore.collection("users").document(currentUid)
            .collection("ai_domain_detections").document(domain)
        val existing = detectionRef.get().await()
        if (existing.exists() && DetectionCache.isFresh(existing)) {
            Log.i(TAG, "Skip $domain — cached AI result still fresh")
            return Result.success()
        }

        Log.i(TAG, "Classifying domain=$domain uid=$currentUid")
        val result = GeminiClassifier.classifyDomain(domain)
        if (result == null) {
            return if (runAttemptCount < AiConfig.MAX_RETRIES) Result.retry() else Result.failure()
        }
        Log.i(TAG, "Writing ai_domain_detections/$domain -> ${result.classification} (${result.confidence})")

        detectionRef.set(
            mapOf(
                "name" to domain,
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
                    "type" to "domain",
                    "key" to domain,
                    "name" to domain,
                    "classification" to result.classification,
                    "confidence" to result.confidence,
                    "reason" to result.reason,
                    "reportedByUid" to currentUid,
                    "model" to GeminiClassifier.MODEL_NAME,
                    "classifierVersion" to GeminiClassifier.CLASSIFIER_VERSION,
                    "detectedAt" to Date(),
                ),
            ).await()
            Log.i(
                TAG,
                if (result.confidence >= AiConfig.HIGH_CONFIDENCE_THRESHOLD) {
                    "High-confidence gambling — $domain enters the effective block set"
                } else {
                    "Medium-confidence gambling — $domain cached only, no suggestion UI for domains yet"
                },
            )
        }

        return Result.success()
    }

    companion object {
        private const val TAG = "SawataDomainClassifyWorker"
        private const val KEY_UID = "uid"
        private const val KEY_DOMAIN = "domain"

        fun enqueue(context: Context, uid: String, domain: String) {
            val data = workDataOf(KEY_UID to uid, KEY_DOMAIN to domain)
            val request = OneTimeWorkRequestBuilder<DomainClassificationWorker>()
                .setInputData(data)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, WorkRequest.MIN_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                "ai-classify-domain-$uid-$domain",
                ExistingWorkPolicy.KEEP,
                request,
            )
        }
    }
}
