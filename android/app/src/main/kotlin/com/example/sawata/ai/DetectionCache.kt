package com.example.sawata.ai

import com.google.firebase.firestore.DocumentSnapshot
import java.util.concurrent.TimeUnit

/**
 * Decides whether a cached `ai_app_detections`/`ai_domain_detections` doc is
 * still trustworthy enough to skip re-classifying. A "gambling" verdict is
 * treated as sticky (an app doesn't stop being a gambling app), but
 * not_gambling/uncertain verdicts expire — the classifier can be wrong, and
 * an app's own behavior can change after an update. A classifierVersion
 * mismatch always forces a re-check regardless of age, since it means the
 * prompt/schema this doc was classified under is no longer what
 * [com.example.sawata.ai.GeminiClassifier] uses.
 */
object DetectionCache {
    fun isFresh(doc: DocumentSnapshot): Boolean {
        val classification = doc.getString("classification") ?: return false
        val version = doc.getString("classifierVersion")
        if (version != GeminiClassifier.CLASSIFIER_VERSION) return false
        if (classification == "gambling") return true
        val classifiedAt = doc.getTimestamp("classifiedAt")?.toDate() ?: return false
        val age = System.currentTimeMillis() - classifiedAt.time
        return age < TimeUnit.DAYS.toMillis(AiConfig.RECLASSIFY_AFTER_DAYS)
    }
}
