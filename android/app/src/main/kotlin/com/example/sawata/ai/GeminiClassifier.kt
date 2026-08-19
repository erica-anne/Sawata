package com.example.sawata.ai

import android.util.Log
import com.google.firebase.Firebase
import com.google.firebase.ai.ai
import com.google.firebase.ai.type.GenerativeBackend
import com.google.firebase.ai.type.Schema
import com.google.firebase.ai.type.generationConfig
import org.json.JSONObject

/**
 * The single place Sawatâ calls Gemini to classify an app or domain as
 * gambling-related. Runs on Firebase AI Logic's native Android SDK (not the
 * Dart firebase_ai plugin) so it works from a WorkManager job even when the
 * Flutter engine isn't running — e.g. classifying a newly-installed app
 * while Sawatâ itself is closed. This is deliberately the only classifier in
 * the app; nothing else calls Gemini.
 */
object GeminiClassifier {
    private const val TAG = "SawataGeminiClassifier"

    /** Bump when the prompt/schema changes meaningfully — see [DetectionCache]. */
    const val CLASSIFIER_VERSION = "1"

    // Confirmed against the user's own Firebase AI Logic backend (Gemini
    // Developer API) — gemini-2.5-flash was retired for new projects.
    const val MODEL_NAME = "gemini-3.6-flash"

    data class ClassificationResult(
        val classification: String,
        val confidence: Double,
        val reason: String,
    )

    private val responseSchema = Schema.obj(
        mapOf(
            "classification" to Schema.enumeration(listOf("gambling", "not_gambling", "uncertain")),
            "confidence" to Schema.double(),
            "reason" to Schema.string(),
        ),
    )

    private val model by lazy {
        Firebase.ai(backend = GenerativeBackend.googleAI()).generativeModel(
            modelName = MODEL_NAME,
            generationConfig = generationConfig {
                responseMimeType = "application/json"
                responseSchema = this@GeminiClassifier.responseSchema
            },
        )
    }

    suspend fun classifyApp(appName: String, packageName: String): ClassificationResult? = classify(
        "You are a classifier for an Android app that blocks real-money gambling apps. " +
            "Decide whether the following installed app is a real-money gambling app " +
            "(online casino, sports betting, slots, poker for money, or similar). " +
            "App display name: \"$appName\". Android package id: \"$packageName\".",
    )

    suspend fun classifyDomain(domain: String): ClassificationResult? = classify(
        "You are a classifier for an Android app that blocks real-money gambling websites. " +
            "Decide whether the following website domain is a real-money gambling site " +
            "(online casino, sports betting, slots, poker for money, or similar). " +
            "Domain: \"$domain\".",
    )

    private suspend fun classify(prompt: String): ClassificationResult? {
        Log.i(TAG, "Sending Gemini classification request")
        return try {
            val response = model.generateContent(prompt)
            val text = response.text
            if (text == null) {
                Log.w(TAG, "Gemini response had no text")
                return null
            }
            val json = JSONObject(text)
            val result = ClassificationResult(
                classification = json.optString("classification", "uncertain"),
                confidence = json.optDouble("confidence", 0.0),
                reason = json.optString("reason", ""),
            )
            Log.i(TAG, "Gemini classified -> ${result.classification} (confidence=${result.confidence})")
            result
        } catch (e: Exception) {
            Log.w(TAG, "Gemini classification request failed", e)
            null
        }
    }
}
