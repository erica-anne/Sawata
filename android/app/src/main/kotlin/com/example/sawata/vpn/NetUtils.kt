package com.example.sawata.vpn

import java.net.InetAddress

const val PROTOCOL_TCP = 6
const val PROTOCOL_UDP = 17

/** Standard internet checksum (RFC 1071) over an arbitrary byte range. */
fun checksum(data: ByteArray, offset: Int, length: Int, initial: Int = 0): Int {
    var sum = initial
    var i = offset
    val end = offset + length
    while (i < end - 1) {
        val word = ((data[i].toInt() and 0xFF) shl 8) or (data[i + 1].toInt() and 0xFF)
        sum += word
        i += 2
    }
    if (i < end) {
        sum += (data[i].toInt() and 0xFF) shl 8
    }
    while (sum shr 16 != 0) {
        sum = (sum and 0xFFFF) + (sum shr 16)
    }
    return sum
}

fun finalizeChecksum(sum: Int): Int = sum.inv() and 0xFFFF

/** Sum of the IPv4 pseudo-header, used as the `initial` seed for UDP/TCP checksums. */
fun pseudoHeaderSum(srcIp: ByteArray, dstIp: ByteArray, protocol: Int, segmentLength: Int): Int {
    var sum = checksum(srcIp, 0, 4)
    sum = checksum(dstIp, 0, 4, sum)
    sum += protocol
    sum += segmentLength
    return sum
}

fun ByteArray.putShort(offset: Int, value: Int) {
    this[offset] = ((value shr 8) and 0xFF).toByte()
    this[offset + 1] = (value and 0xFF).toByte()
}

fun ByteArray.putInt(offset: Int, value: Int) {
    this[offset] = ((value shr 24) and 0xFF).toByte()
    this[offset + 1] = ((value shr 16) and 0xFF).toByte()
    this[offset + 2] = ((value shr 8) and 0xFF).toByte()
    this[offset + 3] = (value and 0xFF).toByte()
}

fun ByteArray.getUShort(offset: Int): Int =
    ((this[offset].toInt() and 0xFF) shl 8) or (this[offset + 1].toInt() and 0xFF)

fun ByteArray.getUInt(offset: Int): Long {
    return ((this[offset].toLong() and 0xFF) shl 24) or
        ((this[offset + 1].toLong() and 0xFF) shl 16) or
        ((this[offset + 2].toLong() and 0xFF) shl 8) or
        (this[offset + 3].toLong() and 0xFF)
}

fun inetAddressToBytes(address: InetAddress): ByteArray = address.address
