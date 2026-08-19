package com.example.sawata.ai

/**
 * Tunable knobs for AI-based gambling detection. Kept as constants (not a
 * Firestore-backed doc like GamblingKeywords) since these are safety-critical
 * thresholds, not content to curate — changing them ships a new APK on
 * purpose.
 */
object AiConfig {
    /** classification=="gambling" at/above this confidence enters the effective block set. */
    const val HIGH_CONFIDENCE_THRESHOLD = 0.85

    /** not_gambling/uncertain results are re-checked after this many days. */
    const val RECLASSIFY_AFTER_DAYS = 14L

    /** WorkManager retries (via Result.retry()) before giving up on a classification job. */
    const val MAX_RETRIES = 3

    /**
     * How many AppClassificationWorker jobs InstalledAppsScanWorker lets run
     * at once. WorkManager's own executor could in principle run more in
     * parallel, so this is an explicit gate (see InstalledAppsScanWorker),
     * not a hope that the platform default happens to be small.
     */
    const val MAX_CONCURRENT_APP_CLASSIFICATIONS = 3
}
