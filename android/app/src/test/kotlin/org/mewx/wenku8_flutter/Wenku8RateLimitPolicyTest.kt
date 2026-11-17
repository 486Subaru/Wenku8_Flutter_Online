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

    @Test fun smallBurstsRestoreThePreviousNormalSpacing() {
        val pacing = Wenku8RequestPacing()
        assertEquals(0L, pacing.delayMs(0L))
        pacing.markStarted(0L)
        assertEquals(800L, pacing.delayMs(100L))
        assertEquals(0L, pacing.delayMs(900L))
        pacing.markStarted(900L)
        assertEquals(0L, pacing.delayMs(1_800L))
        pacing.markStarted(1_800L)
        assertEquals(2_600L, pacing.delayMs(2_700L))
        assertEquals(0L, pacing.delayMs(5_300L))
        assertEquals(0L, pacing.delayMs(12_000L))
        pacing.markStarted(12_000L)
        assertEquals(0L, pacing.delayMs(12_900L))
    }

    @Test fun independentSearchStillWaitsAfterItsLatestSearchEndpoint() {
        val pacing = Wenku8RequestPacing()
        pacing.markStarted(0L, search = true)
        assertEquals(5_000L, pacing.delayMs(100L, search = true))
        assertEquals(800L, pacing.delayMs(100L, search = true, continuation = true))
        pacing.markStarted(900L, search = true)
        assertEquals(900L, pacing.delayMs(5_100L, search = true))
        assertEquals(0L, pacing.delayMs(6_000L, search = true))
    }

    @Test fun rateLimitRecoveryUsesConservativeSpacingBeforeResumingNormalTraffic() {
        val pacing = Wenku8RequestPacing()
        pacing.recordRateLimit(0L)
        val resume = 900_000L
        pacing.markStarted(resume)
        assertEquals(2_600L, pacing.delayMs(resume + 900L))
        pacing.markStarted(resume + 119_100L)
        assertEquals(0L, pacing.delayMs(resume + 120_000L))
    }

    @Test fun restoringAnActiveCooldownPreservesItsRemainingTimeAndRecoverySpacing() {
        val pacing = Wenku8RequestPacing()
        pacing.restoreCooldown(now = 200L, wallNow = 10_000L, expiresAt = 40_000L)
        assertEquals(30_000L, pacing.remainingCooldownMs(200L))
        assertEquals(0L, pacing.remainingCooldownMs(30_200L))
        pacing.markStarted(30_200L)
        assertEquals(2_600L, pacing.delayMs(31_100L))
        val expired = Wenku8RequestPacing()
        expired.restoreCooldown(now = 200L, wallNow = 40_000L, expiresAt = 40_000L)
        assertEquals(0L, expired.remainingCooldownMs(200L))
        expired.markStarted(200L)
        assertEquals(0L, expired.delayMs(1_100L))
    }

    @Test fun staticImagesUseConservativeSpacingFromTheFirstRequest() {
        val pacing = Wenku8RequestPacing(minimumIntervalMs = 3_500L)
        assertEquals(0L, pacing.delayMs(0L))
        pacing.markStarted(0L)
        assertEquals(2_600L, pacing.delayMs(900L))
        assertEquals(0L, pacing.delayMs(3_500L))
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
