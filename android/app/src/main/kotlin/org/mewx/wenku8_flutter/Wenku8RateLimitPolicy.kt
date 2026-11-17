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
internal class Wenku8RequestPacing(private val minimumIntervalMs: Long = 900L) {
    companion object {
        const val COOLDOWN_MS = 15 * 60_000L
        private const val GUARDED_MS = 2 * 60_000L
    }
    private val recentStarts = ArrayDeque<Long>(3)
    private var lastSearchAt: Long? = null
    @Volatile private var blockedUntil = 0L
    private var guardedUntil = 0L

    fun recordRateLimit(now: Long) {
        setCooldown(now + COOLDOWN_MS)
    }

    fun restoreCooldown(now: Long, wallNow: Long, expiresAt: Long) {
        if (expiresAt <= wallNow) return
        val remaining = (expiresAt - wallNow).coerceAtMost(COOLDOWN_MS)
        setCooldown(now + remaining)
    }

    private fun setCooldown(until: Long) {
        guardedUntil = maxOf(blockedUntil, until) + GUARDED_MS
        recentStarts.clear()
        blockedUntil = maxOf(blockedUntil, until)
    }

    fun remainingCooldownMs(now: Long): Long = (blockedUntil - now).coerceAtLeast(0L)

    fun delayMs(now: Long, search: Boolean = false, continuation: Boolean = false): Long {
        val sustained = recentStarts.size == 3 && now - recentStarts.first() < 10_000L
        val interval = when {
            now < guardedUntil || sustained -> maxOf(3_500L, minimumIntervalMs)
            else -> minimumIntervalMs
        }
        val requestDelay = recentStarts.lastOrNull()?.let { interval - (now - it) } ?: 0L
        val searchDelay = if (search && !continuation) {
            lastSearchAt?.let { 5_100L - (now - it) } ?: 0L
        } else 0L
        return maxOf(requestDelay, searchDelay, 0L)
    }

    fun markStarted(now: Long, search: Boolean = false) {
        if (recentStarts.size == 3) recentStarts.removeFirst()
        recentStarts.addLast(now)
        if (search) lastSearchAt = now
    }
}
