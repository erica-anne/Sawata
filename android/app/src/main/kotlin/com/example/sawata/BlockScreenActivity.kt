package com.example.sawata

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

/**
 * The intervention screen shown when [SawataAccessibilityService] blocks an
 * app. Native (not Flutter) so it appears instantly even if the Flutter
 * engine isn't already warm — the whole point is to interrupt the moment,
 * not to wait on a cold engine start.
 */
class BlockScreenActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block_screen)

        val appName = intent.getStringExtra(EXTRA_APP_NAME)
        if (!appName.isNullOrBlank()) {
            findViewById<TextView>(R.id.block_subtitle).text =
                "Sawatâ stepped in before you could open \"$appName\"."
        }

        findViewById<android.widget.Button>(R.id.back_to_safety_button)
            .setOnClickListener { finish() }
    }

    companion object {
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_APP_NAME = "extra_app_name"
    }
}
