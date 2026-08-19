package com.example.sawata.ai

import android.util.Log
import com.google.firebase.Firebase
import com.google.firebase.appcheck.appCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory

/**
 * RELEASE variant — the debug provider class isn't even on this build's
 * classpath (see build.gradle.kts: firebase-appcheck-debug is
 * debugImplementation-only), so it's structurally impossible for a release
 * build to activate it, not just unlikely.
 */
object AppCheckActivator {
    private const val TAG = "SawataAppCheck"

    fun activate() {
        Firebase.appCheck.installAppCheckProviderFactory(PlayIntegrityAppCheckProviderFactory.getInstance())
        Log.i(TAG, "Activated Play Integrity App Check provider (release build)")
    }
}
