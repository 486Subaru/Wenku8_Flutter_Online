package org.mewx.wenku8_flutter

/** Recognize rate-limit pages, including servers returning them with HTTP 200. */
internal object Wenku8RateLimitPolicy {
    fun isRateLimited(status: Int, html: String): Boolean =
        status == 429 || isCloudflareRateLimited(html)

    fun isCloudflareRateLimited(html: String): Boolean {
        val text = html.lowercase()
        return (text.contains("error 1015") && text.contains("cloudflare")) ||
            (text.contains("you are being rate limited") && text.contains("cloudflare"))
    }
}

/** Accessed by the serialized official request worker, using monotonic milliseconds. */
internal class Wenku8RequestPacing {
    private val recentStarts = ArrayDeque<Long>(3)
    private var lastSearchAt: Long? = null
    private var blockedUntil = 0L
    private var guardedUntil = 0L

    fun recordRateLimit(now: Long) {
        blockedUntil = maxOf(blockedUntil, now + 15 * 60_000L)
        guardedUntil = blockedUntil + 2 * 60_000L
        recentStarts.clear()
    }

    fun remainingCooldownMs(now: Long): Long = (blockedUntil - now).coerceAtLeast(0L)

    fun delayMs(now: Long, search: Boolean = false): Long {
        val requestDelay = lastStartedAt?.let { 3_500L - (now - it) } ?: 0L
        val searchDelay = if (search) lastSearchAt?.let { 5_100L - (now - it) } ?: 0L else 0L
        return maxOf(requestDelay, searchDelay, 0L)
    }

    fun markStarted(now: Long, search: Boolean = false) {
        lastStartedAt = now
        if (search) lastSearchAt = now
    }
}
