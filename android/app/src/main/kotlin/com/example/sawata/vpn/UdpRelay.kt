package com.example.sawata.vpn

import android.net.VpnService
import android.util.Log
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.SocketTimeoutException
import java.util.concurrent.ConcurrentHashMap

/**
 * Relays UDP packets (DNS queries in particular, plus anything else UDP —
 * e.g. QUIC/HTTP3) out to the real internet and pipes responses back into
 * the tunnel. Each local (srcPort, destination) flow gets one real
 * [DatagramSocket], reused for follow-up packets and read continuously by a
 * background thread until it goes idle.
 */
class UdpRelay(private val vpnService: VpnService, private val output: FileOutputStream) {

    private data class SessionKey(val srcPort: Int, val dstAddress: String, val dstPort: Int)

    private class Session(val socket: DatagramSocket)

    private val sessions = ConcurrentHashMap<SessionKey, Session>()

    fun handle(packet: Ipv4Packet) {
        val udp = packet.raw
        val offset = packet.payloadOffset
        if (packet.payloadLength < UDP_HEADER_LENGTH) return

        val srcPort = udp.getUShort(offset)
        val dstPort = udp.getUShort(offset + 2)
        val payloadLength = packet.payloadLength - UDP_HEADER_LENGTH
        val payload = udp.copyOfRange(offset + UDP_HEADER_LENGTH, offset + UDP_HEADER_LENGTH + payloadLength)

        if (dstPort == DNS_PORT) {
            val hostname = DnsUtils.parseQuestionName(payload)
            if (hostname != null && DomainBlocklist.isBlocked(hostname)) {
                writeUdpReturnPacket(
                    localAddress = packet.sourceAddress,
                    localPort = srcPort,
                    remoteAddress = packet.destinationAddress,
                    remotePort = dstPort,
                    payload = DnsUtils.buildNxDomainResponse(payload),
                )
                return
            }
            // Not blocked — cheap, synchronous, in-memory-only prefilter
            // decides whether this is even worth queueing for AI
            // classification. Gemini never runs on this thread; see
            // DomainBlocklist.maybeQueueForClassification.
            if (hostname != null) {
                DomainBlocklist.maybeQueueForClassification(vpnService, hostname)
            }
        }

        val key = SessionKey(srcPort, packet.destinationAddress.hostAddress ?: return, dstPort)
        val session = sessions.getOrPut(key) { createSession(key, packet) } ?: return

        try {
            session.socket.send(
                DatagramPacket(payload, payload.size, InetSocketAddress(packet.destinationAddress, dstPort)),
            )
        } catch (e: Exception) {
            Log.w(TAG, "UDP send failed for $key", e)
            sessions.remove(key)
            session.socket.close()
        }
    }

    private fun createSession(key: SessionKey, packet: Ipv4Packet): Session? {
        val socket = DatagramSocket()
        if (!vpnService.protect(socket)) {
            Log.w(TAG, "Failed to protect UDP socket for $key")
            socket.close()
            return null
        }
        socket.soTimeout = SESSION_IDLE_TIMEOUT_MS
        val session = Session(socket)

        // Local (device-side) address for building return packets — fixed
        // per flow, taken from the packet that opened this session.
        val localAddress = packet.sourceAddress
        val remoteAddress = packet.destinationAddress

        Thread({
            val buffer = ByteArray(MAX_UDP_PAYLOAD)
            try {
                while (!socket.isClosed) {
                    val response = DatagramPacket(buffer, buffer.size)
                    try {
                        socket.receive(response)
                    } catch (e: SocketTimeoutException) {
                        break // idle — tear this session down
                    }
                    writeUdpReturnPacket(
                        localAddress = localAddress,
                        localPort = key.srcPort,
                        remoteAddress = remoteAddress,
                        remotePort = key.dstPort,
                        payload = response.data.copyOfRange(0, response.length),
                    )
                }
            } catch (e: Exception) {
                Log.w(TAG, "UDP session $key ended", e)
            } finally {
                sessions.remove(key)
                socket.close()
            }
        }, "sawata-udp-$key").apply { isDaemon = true }.start()

        return session
    }

    @Synchronized
    private fun writeUdpReturnPacket(
        localAddress: java.net.InetAddress,
        localPort: Int,
        remoteAddress: java.net.InetAddress,
        remotePort: Int,
        payload: ByteArray,
    ) {
        val segment = ByteArray(UDP_HEADER_LENGTH + payload.size)
        segment.putShort(0, remotePort) // now sourced FROM the remote server
        segment.putShort(2, localPort) // TO the original local requester
        segment.putShort(4, segment.size)
        segment.putShort(6, 0) // checksum 0 is valid/optional for IPv4 UDP
        System.arraycopy(payload, 0, segment, UDP_HEADER_LENGTH, payload.size)

        val ipPacket = Ipv4Packet.build(
            protocol = PROTOCOL_UDP,
            sourceAddress = remoteAddress,
            destinationAddress = localAddress,
            segment = segment,
        )
        try {
            output.write(ipPacket)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to write UDP return packet", e)
        }
    }

    companion object {
        private const val TAG = "SawataUdpRelay"
        private const val UDP_HEADER_LENGTH = 8
        private const val MAX_UDP_PAYLOAD = 65507
        private const val SESSION_IDLE_TIMEOUT_MS = 30_000
        private const val DNS_PORT = 53
    }
}
