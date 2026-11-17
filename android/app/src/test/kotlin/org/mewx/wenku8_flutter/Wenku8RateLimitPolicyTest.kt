package org.mewx.wenku8_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Wenku8RateLimitPolicyTest {
    @Test fun recognizes1015EvenWithStatus200() {
        assertTrue(Wenku8RateLimitPolicy.isRateLimited(200, "<title>Error 1015</title> You are being rate limited - Cloudflare"))
    }
    @Test fun recognizesHttp429() {
        assertTrue(Wenku8RateLimitPolicy.isRateLimited(429, ""))
    }
    @Test fun doesNotMatchOrdinaryBookText() {
        assertFalse(Wenku8RateLimitPolicy.isRateLimited(200, "小说正文包含 Error 1015 一句话"))
    }

    @Test fun normalSearchAndPagesShareOneShortInterval() {
        val pacing = Wenku8RequestPacing()
        assertEquals(0L, pacing.delayMs(0L))
        pacing.markStarted(0L)
        assertEquals(800L, pacing.delayMs(100L))
        assertEquals(0L, pacing.delayMs(900L))
    }

    @Test fun blocksRequestsThenGraduallyReturnsToNormalPacing() {
        val pacing = Wenku8RequestPacing()
        pacing.markStarted(0L)
        pacing.recordRateLimit(100L)
        val resumeAt = 900_100L
        assertEquals(900_000L, pacing.remainingCooldownMs(100L))
        assertEquals(1L, pacing.remainingCooldownMs(resumeAt - 1))
        assertEquals(0L, pacing.remainingCooldownMs(resumeAt))
        assertEquals(0L, pacing.delayMs(resumeAt))
        pacing.markStarted(resumeAt)
        assertEquals(3_400L, pacing.delayMs(resumeAt + 100L))
        val normalAt = resumeAt + 300_000L
        pacing.markStarted(normalAt - 100L)
        assertEquals(800L, pacing.delayMs(normalAt))
    }
}
