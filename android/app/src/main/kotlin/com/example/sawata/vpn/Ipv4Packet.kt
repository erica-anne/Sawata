package com.example.sawata.vpn

import java.net.InetAddress

/** A parsed IPv4 packet read off the TUN interface. */
class Ipv4Packet private constructor(
    val raw: ByteArray,
    val totalLength: Int,
    val headerLength: Int,
    val protocol: Int,
    val sourceAddress: InetAddress,
    val destinationAddress: InetAddress,
) {
    val payloadOffset: Int get() = headerLength
    val payloadLength: Int get() = totalLength - headerLength

    companion object {
        private const val MIN_HEADER_LENGTH = 20

        /** Returns null for anything that isn't a well-formed IPv4 packet. */
        fun parse(data: ByteArray, length: Int): Ipv4Packet? {
            if (length < MIN_HEADER_LENGTH) return null
            val version = (data[0].toInt() and 0xFF) shr 4
            if (version != 4) return null
            val headerLength = (data[0].toInt() and 0x0F) * 4
            if (headerLength < MIN_HEADER_LENGTH || headerLength > length) return null
            val protocol = data[9].toInt() and 0xFF
            val src = InetAddress.getByAddress(data.copyOfRange(12, 16))
            val dst = InetAddress.getByAddress(data.copyOfRange(16, 20))
            return Ipv4Packet(data, length, headerLength, protocol, src, dst)
        }

        /**
         * Builds a complete IPv4 packet (header + already-built segment) ready to
         * write back into the TUN interface, with a correct header checksum.
         */
        fun build(
            protocol: Int,
            sourceAddress: InetAddress,
            destinationAddress: InetAddress,
            segment: ByteArray,
        ): ByteArray {
            val header = ByteArray(MIN_HEADER_LENGTH)
            val totalLength = MIN_HEADER_LENGTH + segment.size
            header[0] = (4 shl 4 or (MIN_HEADER_LENGTH / 4)).toByte() // version 4, IHL 5
            header[1] = 0 // DSCP/ECN
            header.putShort(2, totalLength)
            header.putShort(4, 0) // identification
            header.putShort(6, 0x4000) // flags: don't fragment
            header[8] = 64 // TTL
            header[9] = protocol.toByte()
            header.putShort(10, 0) // checksum placeholder
            System.arraycopy(inetAddressToBytes(sourceAddress), 0, header, 12, 4)
            System.arraycopy(inetAddressToBytes(destinationAddress), 0, header, 16, 4)
            val sum = finalizeChecksum(checksum(header, 0, MIN_HEADER_LENGTH))
            header.putShort(10, sum)

            val packet = ByteArray(totalLength)
            System.arraycopy(header, 0, packet, 0, MIN_HEADER_LENGTH)
            System.arraycopy(segment, 0, packet, MIN_HEADER_LENGTH, segment.size)
            return packet
        }
    }
}
