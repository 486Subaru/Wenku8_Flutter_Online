package org.mewx.wenku8_flutter

import java.net.URLDecoder

internal data class LightNovelCredentials(
    val securityKey: String,
    val uid: String,
)

/** Parses the path-scoped token cookie used by Light Novel Kingdom's PC API. */
internal object LightNovelTokenParser {
    private val securityKeyPattern =
        Regex("\"security_key\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"")

    fun fromCookieHeader(cookieHeader: String?): LightNovelCredentials? {
        val token = cookieHeader.orEmpty()
            .split(';')
            .map { it.trim() }
            .firstOrNull { it.startsWith("token=") }
            ?.substringAfter('=')
            ?.trim()
            .orEmpty()
        if (token.isEmpty()) return null
        return parseTokenValue(token)
    }

    fun parseTokenValue(rawToken: String): LightNovelCredentials? {
        var candidate = rawToken.trim().removeSurrounding("\"")
        repeat(4) {
            val match = securityKeyPattern.find(candidate)
            if (match != null) {
                val key = unescapeJsonString(match.groupValues[1])
                val uid = key.split(':').getOrNull(1).orEmpty()
                if (key.isNotBlank() && uid.isNotBlank()) {
                    return LightNovelCredentials(key, uid)
                }
            }
            // decodeURIComponent semantics: '+' is a literal plus, not a space.
            val decoded = runCatching {
                URLDecoder.decode(candidate.replace("+", "%2B"), "UTF-8")
            }.getOrDefault(candidate)
            if (decoded == candidate) return null
            candidate = decoded
        }
        return null
    }

    private fun unescapeJsonString(value: String): String =
        value.replace("\\/", "/")
            .replace("\\\"", "\"")
            .replace("\\\\", "\\")
}
