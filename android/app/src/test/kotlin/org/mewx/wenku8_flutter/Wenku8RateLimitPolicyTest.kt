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

    @Test fun ordinaryTrafficRetainsTheConservativeSpacing() {
        val pacing = Wenku8RequestPacing()
        assertEquals(0L, pacing.delayMs(0L))
        pacing.markStarted(0L)
        assertEquals(2_600L, pacing.delayMs(900L))
        assertEquals(0L, pacing.delayMs(3_500L))
    }

    @Test fun usesTheLongerOfSearchAndGlobalSpacing() {
        val pacing = Wenku8RequestPacing()
        pacing.markStarted(0L, search = true)
        assertEquals(1_600L, pacing.delayMs(3_500L, search = true))
        assertEquals(0L, pacing.delayMs(3_500L))
        pacing.markStarted(3_500L)
        assertEquals(1_900L, pacing.delayMs(5_100L, search = true))
        assertEquals(0L, pacing.delayMs(7_000L, search = true))
    }

    @Test fun stopsUntilTheCooldownExpiresWithoutMovingItOnARejectedRequest() {
        val pacing = Wenku8RequestPacing()
        pacing.markStarted(0L, search = true)
        pacing.recordRateLimit(100L)
        val resumeAt = 900_100L
        assertEquals(900_000L, pacing.remainingCooldownMs(100L))
        assertEquals(1L, pacing.remainingCooldownMs(resumeAt - 1))
        assertEquals(0L, pacing.remainingCooldownMs(resumeAt))
        assertEquals(0L, pacing.delayMs(resumeAt, search = true))
        pacing.markStarted(resumeAt, search = true)
        assertEquals(5_000L, pacing.delayMs(resumeAt + 100L, search = true))
    }
}
