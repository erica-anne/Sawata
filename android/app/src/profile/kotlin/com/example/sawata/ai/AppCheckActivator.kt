package com.example.sawata.ai

import android.util.Log
import com.google.firebase.Firebase
import com.google.firebase.appcheck.appCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory

/**
 * PROFILE variant — a real signed(ish) build used for performance testing,
 * so it must behave like release, not debug. See src/debug's version of this
 * file for why this is a compile-time split rather than a runtime if-check.
 */
object AppCheckActivator {
    private const val TAG = "SawataAppCheck"

    fun activate() {
        Firebase.appCheck.installAppCheckProviderFactory(PlayIntegrityAppCheckProviderFactory.getInstance())
        Log.i(TAG, "Activated Play Integrity App Check provider (profile build)")
    }
}
