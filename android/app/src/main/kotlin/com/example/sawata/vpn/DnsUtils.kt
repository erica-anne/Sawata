package com.example.sawata.vpn

/**
 * Minimal DNS message helpers for query interception — just enough to read
 * the hostname a client is asking about and to synthesize an NXDOMAIN reply.
 * Not a general-purpose DNS library (no compression-pointer support, no
 * multi-question handling): outgoing client queries are always a single,
 * uncompressed question, which is all we need to intercept.
 */
object DnsUtils {
    private const val HEADER_LENGTH = 12

    /** Reads the first question's QNAME (e.g. "www.example.com"), or null if malformed. */
    fun parseQuestionName(payload: ByteArray): String? = parseQuestion(payload)?.first

    /**
     * Builds a complete DNS response message for [query] with RCODE=3
     * (NXDOMAIN): same ID and question section, QR=1, RA=1, zero answers.
     * [query] must already have parsed successfully via [parseQuestionName].
     */
    fun buildNxDomainResponse(query: ByteArray): ByteArray {
        val questionEnd = parseQuestion(query)?.second ?: HEADER_LENGTH
        val response = ByteArray(questionEnd)
        System.arraycopy(query, 0, response, 0, questionEnd)

        // Preserve the client's RD bit (recursion desired) and set RA=1.
        val rd = query[2].toInt() and 0x01
        response[2] = (0x80 or rd).toByte() // QR=1, Opcode=0, AA=0, TC=0, RD=copied
        response[3] = (0x80 or 0x03).toByte() // RA=1, Z=0, RCODE=3 (NXDOMAIN)

        response.putShort(6, 0) // ANCOUNT
        response.putShort(8, 0) // NSCOUNT
        response.putShort(10, 0) // ARCOUNT
        return response
    }

    /** Walks the question section, returning (dotted QNAME, offset just past QTYPE/QCLASS). */
    private fun parseQuestion(payload: ByteArray): Pair<String, Int>? {
        if (payload.size <= HEADER_LENGTH) return null
        if (payload.getUShort(4) < 1) return null // QDCOUNT

        val labels = mutableListOf<String>()
        var offset = HEADER_LENGTH
        while (offset < payload.size) {
            val length = payload[offset].toInt() and 0xFF
            if (length == 0) {
                offset += 1
                // Needs QTYPE(2) + QCLASS(2) to follow for a valid question.
                return if (offset + 4 <= payload.size) labels.joinToString(".") to offset + 4 else null
            }
            // Compression pointers (top two bits set) don't occur in a
            // client's outgoing question section — bail out if seen.
            if (length and 0xC0 != 0) return null
            offset += 1
            if (offset + length > payload.size) return null
            labels.add(String(payload, offset, length, Charsets.US_ASCII))
            offset += length
        }
        return null
    }
}
