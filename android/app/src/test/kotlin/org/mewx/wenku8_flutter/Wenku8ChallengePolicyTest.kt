package org.mewx.wenku8_flutter

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Wenku8ChallengePolicyTest {
    @Test
    fun normalCatalogWithCloudflareScriptIsNotAChallenge() {
        val html = """<title>轻小说文库</title><a href="/book/123.htm">小说</a><script src="/cdn-cgi/challenge-platform/sample.js"></script>"""
        assertFalse(Wenku8ChallengePolicy.isChallenge(html, null))
    }

    @Test
    fun explicitChallengeHeaderIsRecognized() {
        assertTrue(Wenku8ChallengePolicy.isChallenge("", "challenge"))
    }

    @Test
    fun challengeTitleIsRecognized() {
        assertTrue(Wenku8ChallengePolicy.isChallenge("<title>Just a moment...</title>", null))
    }

    @Test
    fun challengeFormAndScriptAreRecognized() {
        val html = """<form id="challenge-form"></form><script>window._cf_chl_opt = {};</script>"""
        assertTrue(Wenku8ChallengePolicy.isChallenge(html, null))
    }

    @Test
    fun unrelatedErrorPageIsNotAChallenge() {
        assertFalse(Wenku8ChallengePolicy.isChallenge("<title>403 Forbidden</title>", null))
    }
}
