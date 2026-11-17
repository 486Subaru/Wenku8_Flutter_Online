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
    private var lastStartedAt: Long? = null
    private var blockedUntil = 0L

    fun recordRateLimit(now: Long) {
        blockedUntil = maxOf(blockedUntil, now + 15 * 60_000L)
    }

    fun remainingCooldownMs(now: Long): Long = (blockedUntil - now).coerceAtLeast(0L)

    fun delayMs(now: Long): Long {
        val last = lastStartedAt ?: return 0L
        val recovering = blockedUntil != 0L && now - blockedUntil < 5 * 60_000L
        val interval = if (recovering) 3500L else 900L
        return (interval - (now - last)).coerceAtLeast(0L)
    }

    fun markStarted(now: Long) {
        lastStartedAt = now
    }
}
