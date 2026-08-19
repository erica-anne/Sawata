package com.example.sawata

import android.util.Log
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

/**
 * Live-updatable curated keyword list for flagging likely gambling apps by
 * label/package name, backed by the `app_config/gambling_keywords` Firestore
 * doc (a single `keywords: string[]` field) — same reasoning as
 * `DomainBlocklist` (android/app/.../vpn/DomainBlocklist.kt): tunable without
 * shipping a new APK. Used by [SawataAccessibilityService] to *suggest*
 * blocking a newly-opened app, never to block it outright.
 */
object GamblingKeywords {
    private const val TAG = "GamblingKeywords"

    // "bet" alone is too generic (matches "Alphabet", "Better Homes", etc.)
    // — only counts as a match on its own word boundary.
    private val betRegex = Regex("\\bbet\\b", RegexOption.IGNORE_CASE)

    @Volatile private var keywords: List<String> = emptyList()
    private var registration: ListenerRegistration? = null

    fun start() {
        if (registration != null) return
        registration = FirebaseFirestore.getInstance()
            .collection("app_config")
            .document("gambling_keywords")
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    Log.w(TAG, "gambling_keywords listener error", error)
                    return@addSnapshotListener
                }
                @Suppress("UNCHECKED_CAST")
                val list = snapshot?.get("keywords") as? List<String> ?: emptyList()
                keywords = list.map { it.lowercase() }
            }
    }

    fun stop() {
        registration?.remove()
        registration = null
    }

    fun matches(appName: String, packageName: String): Boolean = matchesText("$appName $packageName")

    /**
     * Same keyword/regex check as [matches], but for arbitrary text — used
     * by DomainBlocklist as a cheap prefilter on hostnames before an unknown
     * domain is even considered for AI classification.
     */
    fun matchesText(text: String): Boolean {
        val haystack = text.lowercase()
        if (betRegex.containsMatchIn(haystack)) return true
        return keywords.any { it.isNotBlank() && haystack.contains(it) }
    }
}
