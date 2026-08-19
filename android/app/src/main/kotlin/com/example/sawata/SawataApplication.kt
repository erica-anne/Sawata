package com.example.sawata

import android.app.Application
import com.example.sawata.ai.AppCheckActivator
import com.google.firebase.FirebaseApp

/**
 * Activates native Firebase App Check in Application.onCreate() — before
 * MainActivity/the Flutter engine, and before any WorkManager job that might
 * run while the Flutter engine was never started (e.g. AppClassificationWorker
 * triggered by AppInstallReceiver right after an install). Both need a
 * working App Check token to call Gemini via GeminiClassifier.
 */
class SawataApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)
        AppCheckActivator.activate()
    }
}
