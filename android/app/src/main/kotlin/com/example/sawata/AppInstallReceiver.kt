package com.example.sawata

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.sawata.ai.AppClassificationWorker
import com.google.firebase.auth.FirebaseAuth

/**
 * Manifest-registered (survives the app process being dead) receiver for
 * PACKAGE_ADDED. Does ONLY the minimum to stay well under the broadcast
 * receiver's ANR window: reads the package name and the current signed-in
 * uid (both local/cached, no I/O) and hands off to WorkManager. All real
 * work — network calls, Firestore reads/writes, Gemini — happens later in
 * [AppClassificationWorker], never here.
 */
class AppInstallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_PACKAGE_ADDED) return
        val packageName = intent.data?.schemeSpecificPart ?: return
        if (packageName == context.packageName) return

        // An update re-fires PACKAGE_ADDED with EXTRA_REPLACING=true — that's
        // not a new install. Still worth a classification pass (the app's
        // behavior can change), but AppClassificationWorker treats it as an
        // invalidation of a stale not_gambling/uncertain cache entry, not a
        // fresh "new app" event.
        val isUpdate = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)

        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            Log.i(TAG, "PACKAGE_ADDED pkg=$packageName ignored — no signed-in user")
            return
        }

        Log.i(TAG, "PACKAGE_ADDED pkg=$packageName isUpdate=$isUpdate uid=$uid — enqueueing classification")
        AppClassificationWorker.enqueue(context.applicationContext, uid, packageName, isUpdate)
    }

    companion object {
        private const val TAG = "SawataAppInstallReceiver"
    }
}
