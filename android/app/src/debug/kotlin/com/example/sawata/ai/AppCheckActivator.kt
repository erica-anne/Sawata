package com.example.sawata.ai

import android.util.Log
import com.google.firebase.Firebase
import com.google.firebase.appcheck.appCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory

/**
 * DEBUG variant only — lives under src/debug/kotlin, so the debug provider
 * class isn't even on the classpath for profile/release builds (see the
 * matching files under src/profile and src/release). That's a compile-time
 * guarantee, not a runtime if-check: a release build physically cannot wire
 * up the debug provider by accident.
 */
object AppCheckActivator {
    private const val TAG = "SawataAppCheck"

    fun activate() {
        Firebase.appCheck.installAppCheckProviderFactory(DebugAppCheckProviderFactory.getInstance())
        Log.i(
            TAG,
            "Activated DEBUG App Check provider. Check logcat for the debug token line and " +
                "register it in Firebase Console -> App Check -> Apps -> Manage debug tokens.",
        )
    }
}
