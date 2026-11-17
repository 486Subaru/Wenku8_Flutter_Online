package org.mewx.wenku8_flutter

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
}
