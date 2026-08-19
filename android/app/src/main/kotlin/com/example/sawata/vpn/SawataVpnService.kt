package com.example.sawata.vpn

import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException

/**
 * Phase 3 (feature/vpn-service plan): a working pass-through tunnel with DNS-
 * level gambling-domain blocking. Captures all IPv4 traffic and relays it to
 * the actual internet via [UdpRelay] / [TcpRelay] so normal browsing keeps
 * working, except [UdpRelay] answers DNS queries for domains in
 * [DomainBlocklist] with NXDOMAIN instead of forwarding them. This only
 * covers plain DNS (UDP/53) — apps/browsers using DNS-over-HTTPS or a
 * hardcoded IP can still bypass it; SNI-based filtering in [TcpRelay] would
 * close that gap and is a later phase.
 */
class SawataVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    @Volatile private var running = false
    private var relayThread: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // Closing the tunnel's ParcelFileDescriptor here, from inside the
            // service, is what actually makes the system revoke the VPN
            // network. Calling Context.stopService() from MainActivity alone
            // isn't reliable: once established, the system holds its own
            // binding to this service to manage the VPN network, and plain
            // stopService()/onDestroy() can leave that binding — and the
            // tunnel — alive indefinitely (confirmed via `adb shell am
            // stopservice`, which errors out on this exact service while the
            // tunnel is up).
            teardown()
            stopSelf()
            return START_NOT_STICKY
        }
        if (vpnInterface == null) {
            val builder = Builder()
                .setSession("Sawatâ")
                .addAddress(TUNNEL_ADDRESS, 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                .setMtu(MTU)
            try {
                // Sawatâ must never tunnel its own traffic (Firebase Auth,
                // Google Sign-In, Firestore) — otherwise its own network
                // calls get captured by this same tunnel and depend on
                // protect() to escape it. On some devices/configurations
                // protect() can fail, which silently breaks the app's own
                // login. Excluding the app outright avoids that dependency.
                builder.addDisallowedApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                Log.w(TAG, "Could not exclude own package from VPN", e)
            }
            vpnInterface = builder.establish()

            if (vpnInterface == null) {
                Log.e(TAG, "establish() returned null — VPN permission not granted?")
                stopSelf()
                return START_NOT_STICKY
            }

            running = true
            isRunning = true
            DomainBlocklist.start()
            relayThread = Thread({ runRelay() }, "sawata-vpn-relay").apply { isDaemon = true }
            relayThread?.start()
            Log.i(TAG, "VPN tunnel established with pass-through relay")
        }
        return START_STICKY
    }

    private fun runRelay() {
        val iface = vpnInterface ?: return
        val input = FileInputStream(iface.fileDescriptor)
        val output = FileOutputStream(iface.fileDescriptor)
        val udpRelay = UdpRelay(this, output)
        val tcpRelay = TcpRelay(this, output)
        val buffer = ByteArray(MTU)

        while (running) {
            val length = try {
                input.read(buffer)
            } catch (e: IOException) {
                if (running) Log.w(TAG, "Relay read error", e)
                break
            }
            if (length <= 0) continue

            try {
                val packet = Ipv4Packet.parse(buffer.copyOf(length), length) ?: continue
                when (packet.protocol) {
                    PROTOCOL_UDP -> udpRelay.handle(packet)
                    PROTOCOL_TCP -> tcpRelay.handle(packet)
                    // Other protocols (e.g. ICMP/ping) aren't forwarded yet.
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to process a packet", e)
            }
        }
    }

    /** Idempotent — safe to call from both the explicit stop path and onDestroy(). */
    private fun teardown() {
        if (!running && vpnInterface == null) return
        running = false
        isRunning = false
        DomainBlocklist.stop()
        relayThread?.interrupt()
        try {
            vpnInterface?.close()
        } catch (e: IOException) {
            Log.w(TAG, "Error closing VPN interface", e)
        }
        vpnInterface = null
        Log.i(TAG, "VPN session stopped")
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    override fun onRevoke() {
        // User revoked VPN permission from Android system settings.
        teardown()
        stopSelf()
        super.onRevoke()
    }

    companion object {
        private const val TAG = "SawataVpnService"
        private const val TUNNEL_ADDRESS = "10.0.0.2"
        private const val MTU = 1500

        /** Action for a start Intent that means "tear down the tunnel and stop", not "start it". */
        const val ACTION_STOP = "com.example.sawata.vpn.action.STOP"

        /** Whether an instance of this service currently has the tunnel up. */
        @Volatile var isRunning = false
            private set
    }
}
