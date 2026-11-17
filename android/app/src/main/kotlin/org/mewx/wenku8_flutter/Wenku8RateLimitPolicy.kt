package org.mewx.wenku8_flutter

/** Recognize rate-limit pages, including servers returning them with HTTP 200. */
internal object Wenku8RateLimitPolicy {
    fun isRateLimited(status: Int, html: String): Boolean {
        if (status == 429) return true
        val text = html.lowercase()
        return (text.contains("error 1015") && text.contains("cloudflare")) ||
            (text.contains("you are being rate limited") && text.contains("cloudflare"))
    }
}
