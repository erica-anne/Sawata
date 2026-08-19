package com.example.sawata.vpn

import android.net.VpnService
import android.util.Log
import java.io.FileOutputStream
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

private const val TCP_HEADER_MIN_LENGTH = 20

private object TcpFlag {
    const val FIN = 0x01
    const val SYN = 0x02
    const val RST = 0x04
    const val PSH = 0x08
    const val ACK = 0x10
}

data class TcpConnectionKey(val srcPort: Int, val dstAddress: String, val dstPort: Int)

/**
 * Dispatches incoming TCP segments to a [TcpConnection] per (srcPort,
 * destination) flow, opening a new one on SYN.
 */
class TcpRelay(private val vpnService: VpnService, private val output: FileOutputStream) {

    private val connections = ConcurrentHashMap<TcpConnectionKey, TcpConnection>()

    fun handle(packet: Ipv4Packet) {
        val data = packet.raw
        val offset = packet.payloadOffset
        if (packet.payloadLength < TCP_HEADER_MIN_LENGTH) return

        val srcPort = data.getUShort(offset)
        val dstPort = data.getUShort(offset + 2)
        val seq = data.getUInt(offset + 4)
        val ack = data.getUInt(offset + 8)
        val dataOffsetWords = (data[offset + 12].toInt() and 0xFF) shr 4
        val headerLength = dataOffsetWords * 4
        val flags = data[offset + 13].toInt() and 0xFF
        if (headerLength < TCP_HEADER_MIN_LENGTH) return
        val payloadStart = offset + headerLength
        val payloadLength = packet.payloadLength - headerLength
        if (payloadLength < 0) return
        val payload = if (payloadLength > 0) {
            data.copyOfRange(payloadStart, payloadStart + payloadLength)
        } else {
            ByteArray(0)
        }

        val dstAddress = packet.destinationAddress.hostAddress ?: return
        val key = TcpConnectionKey(srcPort, dstAddress, dstPort)

        val existing = connections[key]
        if (existing == null) {
            if (flags and TcpFlag.SYN != 0 && flags and TcpFlag.ACK == 0) {
                val connection = TcpConnection(
                    key = key,
                    localAddress = packet.sourceAddress,
                    remoteAddress = packet.destinationAddress,
                    clientIsn = seq,
                    vpnService = vpnService,
                    output = output,
                    onClosed = { connections.remove(key) },
                )
                connections[key] = connection
                connection.start()
            }
            // A stray ACK/RST/FIN with no known connection has nothing to act on.
            return
        }
        existing.onClientPacket(flags, seq, ack, payload)
    }
}

/**
 * A simplified per-flow TCP relay: handshakes with the client over the tun
 * interface, mirrors data to/from a real protected [Socket] to the actual
 * destination. Deliberately minimal — no retransmission timers, congestion
 * control, or out-of-order reassembly. Good enough for a single ordinary
 * HTTP/HTTPS request/response flow over a normally-behaving local network;
 * not a production-grade TCP/IP stack.
 */
class TcpConnection(
    private val key: TcpConnectionKey,
    private val localAddress: InetAddress,
    private val remoteAddress: InetAddress,
    clientIsn: Long,
    private val vpnService: VpnService,
    private val output: FileOutputStream,
    private val onClosed: () -> Unit,
) {
    private enum class State { CONNECTING, SYN_SENT_TO_CLIENT, ESTABLISHED }

    @Volatile private var clientSeq = (clientIsn + 1) and MASK_32
    @Volatile private var ourSeq = INITIAL_OUR_SEQ
    @Volatile private var state = State.CONNECTING
    @Volatile private var closed = false
    private var socket: Socket? = null

    fun start() {
        Thread({
            try {
                val s = Socket()
                if (!vpnService.protect(s)) throw IOException("VpnService.protect() failed")
                s.connect(InetSocketAddress(remoteAddress, key.dstPort), CONNECT_TIMEOUT_MS)
                socket = s
                sendSynAck()
                state = State.SYN_SENT_TO_CLIENT
                readFromRemoteLoop(s)
            } catch (e: Exception) {
                Log.w(TAG, "TCP connect failed for $key", e)
                sendRst()
                close()
            }
        }, "sawata-tcp-$key").apply { isDaemon = true }.start()
    }

    @Synchronized
    fun onClientPacket(flags: Int, seq: Long, ack: Long, payload: ByteArray) {
        if (closed) return
        if (flags and TcpFlag.RST != 0) {
            close()
            return
        }
        if (state == State.SYN_SENT_TO_CLIENT && flags and TcpFlag.ACK != 0) {
            state = State.ESTABLISHED
        }
        if (payload.isNotEmpty()) {
            if (seq != clientSeq) {
                // Retransmission or out-of-order — re-ack what we already have.
                sendAck()
                return
            }
            try {
                socket?.getOutputStream()?.apply { write(payload); flush() }
            } catch (e: Exception) {
                Log.w(TAG, "TCP write to remote failed for $key", e)
                sendRst()
                close()
                return
            }
            clientSeq = (clientSeq + payload.size) and MASK_32
            sendAck()
        }
        if (flags and TcpFlag.FIN != 0) {
            clientSeq = (clientSeq + 1) and MASK_32
            sendAck()
            try {
                socket?.shutdownOutput()
            } catch (_: Exception) {
                // Remote socket may already be closed — fine.
            }
        }
    }

    private fun readFromRemoteLoop(socket: Socket) {
        val buffer = ByteArray(MAX_SEGMENT)
        try {
            val input = socket.getInputStream()
            while (!closed) {
                val n = input.read(buffer)
                if (n < 0) {
                    sendFin()
                    break
                }
                if (n > 0) sendData(buffer.copyOfRange(0, n))
            }
        } catch (e: Exception) {
            if (!closed) Log.w(TAG, "TCP read from remote failed for $key", e)
        } finally {
            close()
        }
    }

    @Synchronized
    private fun sendSynAck() = sendSegment(flags = TcpFlag.SYN or TcpFlag.ACK, incrementOurSeq = 1)

    @Synchronized
    private fun sendAck() = sendSegment(flags = TcpFlag.ACK)

    @Synchronized
    private fun sendFin() = sendSegment(flags = TcpFlag.FIN or TcpFlag.ACK, incrementOurSeq = 1)

    @Synchronized
    private fun sendRst() = sendSegment(flags = TcpFlag.RST)

    @Synchronized
    private fun sendData(payload: ByteArray) {
        sendSegment(flags = TcpFlag.PSH or TcpFlag.ACK, payload = payload)
        ourSeq = (ourSeq + payload.size) and MASK_32
    }

    private fun sendSegment(flags: Int, payload: ByteArray = ByteArray(0), incrementOurSeq: Int = 0) {
        val header = ByteArray(TCP_HEADER_MIN_LENGTH)
        header.putShort(0, key.dstPort) // segment is FROM the remote server's port...
        header.putShort(2, key.srcPort) // ...TO the original local client port
        header.putInt(4, ourSeq.toInt())
        header.putInt(8, clientSeq.toInt())
        header[12] = ((TCP_HEADER_MIN_LENGTH / 4) shl 4).toByte()
        header[13] = flags.toByte()
        header.putShort(14, DEFAULT_WINDOW)
        header.putShort(16, 0) // checksum placeholder, filled below
        header.putShort(18, 0)

        val segment = ByteArray(header.size + payload.size)
        System.arraycopy(header, 0, segment, 0, header.size)
        System.arraycopy(payload, 0, segment, header.size, payload.size)

        val pseudo = pseudoHeaderSum(
            inetAddressToBytes(remoteAddress),
            inetAddressToBytes(localAddress),
            PROTOCOL_TCP,
            segment.size,
        )
        segment.putShort(16, finalizeChecksum(checksum(segment, 0, segment.size, pseudo)))

        val ipPacket = Ipv4Packet.build(PROTOCOL_TCP, remoteAddress, localAddress, segment)
        try {
            output.write(ipPacket)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to write TCP segment for $key", e)
        }
        if (incrementOurSeq > 0) ourSeq = (ourSeq + incrementOurSeq) and MASK_32
    }

    @Synchronized
    fun close() {
        if (closed) return
        closed = true
        try {
            socket?.close()
        } catch (_: Exception) {
            // Already closed — fine.
        }
        onClosed()
    }

    companion object {
        private const val TAG = "SawataTcpConn"
        private const val CONNECT_TIMEOUT_MS = 8000
        private const val DEFAULT_WINDOW = 65535
        private const val MAX_SEGMENT = 16384
        private const val INITIAL_OUR_SEQ = 1000L
        private const val MASK_32 = 0xFFFFFFFFL
    }
}
