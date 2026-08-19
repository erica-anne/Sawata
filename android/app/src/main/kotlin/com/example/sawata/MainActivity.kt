package com.example.sawata

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.provider.Settings
import com.example.sawata.vpn.SawataVpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val accessibilityChannelName = "sawata/accessibility"
    private val vpnChannelName = "sawata/vpn"
    private val appsChannelName = "sawata/apps"

    /** Held while waiting for the system VPN-consent dialog to resolve. */
    private var pendingVpnPrepareResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, accessibilityChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(isAccessibilityServiceEnabled())
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vpnChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareVPN" -> prepareVpn(result)
                    "startVPN" -> {
                        startVpnService()
                        result.success(true)
                    }
                    "stopVPN" -> {
                        // Not stopService(): once the tunnel is established
                        // the system holds its own binding to this service,
                        // which can make a plain external stopService() a
                        // no-op. Instead, tell the running service to tear
                        // its own tunnel down (see SawataVpnService.ACTION_STOP).
                        startService(
                            Intent(this, SawataVpnService::class.java)
                                .setAction(SawataVpnService.ACTION_STOP)
                        )
                        result.success(true)
                    }
                    "isRunning" -> result.success(SawataVpnService.isRunning)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> getInstalledApps(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Runs off the UI thread — enumerating + icon-encoding ~100-300 apps is
     * too slow to do synchronously on a MethodChannel call. Posts the
     * result back via `runOnUiThread` since Flutter requires MethodChannel
     * results to be delivered on the platform thread.
     */
    private fun getInstalledApps(result: MethodChannel.Result) {
        Thread {
            val apps = try {
                InstalledAppsProvider.list(applicationContext)
            } catch (e: Exception) {
                null
            }
            runOnUiThread {
                if (apps == null) {
                    result.error("APP_LIST_FAILED", "Could not read installed apps.", null)
                } else {
                    result.success(apps)
                }
            }
        }.start()
    }

    /**
     * `VpnService.prepare()` returns a consent Intent the first time (or
     * whenever a different app currently holds the VPN slot) — null means
     * Sawatâ already has permission and can start immediately.
     */
    private fun prepareVpn(result: MethodChannel.Result) {
        val consentIntent = VpnService.prepare(this)
        if (consentIntent == null) {
            startVpnService()
            result.success(true)
        } else {
            pendingVpnPrepareResult = result
            @Suppress("DEPRECATION")
            startActivityForResult(consentIntent, VPN_REQUEST_CODE)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val granted = resultCode == Activity.RESULT_OK
            if (granted) startVpnService()
            pendingVpnPrepareResult?.success(granted)
            pendingVpnPrepareResult = null
        }
    }

    private fun startVpnService() {
        startService(Intent(this, SawataVpnService::class.java))
    }

    /** Android never lets an app grant this permission for itself — this only reports state. */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponent = "$packageName/${SawataAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.split(":").any { it.equals(expectedComponent, ignoreCase = true) }
    }

    companion object {
        private const val VPN_REQUEST_CODE = 1001
    }
}
