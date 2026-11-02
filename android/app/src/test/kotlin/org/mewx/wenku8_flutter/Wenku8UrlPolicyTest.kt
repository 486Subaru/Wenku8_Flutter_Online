package org.mewx.wenku8_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Wenku8UrlPolicyTest {
    @Test
    fun acceptsOnlyOfficialHttpsPages() {
        assertTrue(Wenku8UrlPolicy.isOfficialPage("https://www.wenku8.net/index.php"))
        assertTrue(Wenku8UrlPolicy.isOfficialPage("https://wenku8.net/modules/article/toplist.php?sort=allvisit"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("http://www.wenku8.net/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://wenku8.net.evil.example/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://user@www.wenku8.net/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://www.wenku8.net:444/index.php"))
    }

    @Test
    fun upgradesOnlyLegacyHttpLinksOnTheOfficialHost() {
        assertEquals(
            "https://www.wenku8.net/login.php?jumpurl=http%3A%2F%2Fwww.wenku8.net%2Findex.php",
            Wenku8UrlPolicy.httpsUpgradeOfficialPage(
                "http://www.wenku8.net/login.php?jumpurl=http%3A%2F%2Fwww.wenku8.net%2Findex.php",
            ),
        )
        assertNull(Wenku8UrlPolicy.httpsUpgradeOfficialPage("http://evil.example/login.php"))
        assertNull(Wenku8UrlPolicy.httpsUpgradeOfficialPage("http://www.wenku8.net:8080/login.php"))
        assertNull(Wenku8UrlPolicy.httpsUpgradeOfficialPage("http://user@www.wenku8.net/login.php"))
    }

    @Test
    fun allowsOnlyCloudflareChallengePaths() {
        assertTrue(
            Wenku8UrlPolicy.isAllowedChallengeUrl(
                "https://challenges.cloudflare.com/cdn-cgi/challenge-platform/h/g/turnstile/if/ov2/av0/rcv",
            ),
        )
        assertTrue(
            Wenku8UrlPolicy.isAllowedChallengeUrl(
                "https://challenges.cloudflare.com/turnstile/v0/api.js",
            ),
        )
        assertFalse(Wenku8UrlPolicy.isAllowedChallengeUrl("https://challenges.cloudflare.com/"))
        assertFalse(Wenku8UrlPolicy.isAllowedChallengeUrl("https://www.cloudflare.com/turnstile/v0/api.js"))
        assertFalse(Wenku8UrlPolicy.isAllowedChallengeUrl("http://challenges.cloudflare.com/turnstile/v0/api.js"))
        assertFalse(Wenku8UrlPolicy.isAllowedChallengeUrl("https://evil.example/cdn-cgi/challenge-platform/test"))
    }

    @Test
    fun acceptsOnlyKnownImageHostsAndImagePaths() {
        assertTrue(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/4/4265/4265s.jpg"))
        assertTrue(Wenku8UrlPolicy.isAllowedImage("https://pic.wenku8.cn/pictures/4/4265/illustration.webp"))
        assertTrue(Wenku8UrlPolicy.isAllowedImage("https://www.wenku8.net/pictures/4/4265/1001/1.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://www.wenku8.net/book/4265.htm"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://evil.example/image/4/4265/4265s.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/4/4265/4265s.jpg?redirect=evil"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/../secret.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("http://img.wenku8.com/image/4/4265/4265s.jpg"))
    }
}
