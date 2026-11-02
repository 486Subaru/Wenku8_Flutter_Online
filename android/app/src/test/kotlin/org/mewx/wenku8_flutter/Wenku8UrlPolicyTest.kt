package org.mewx.wenku8_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Wenku8UrlPolicyTest {
    @Test
    fun acceptsOnlyOfficialHttpsPages() {
        assertTrue(Wenku8UrlPolicy.isOfficialPage("https://www.wenku8.cc/index.php"))
        assertTrue(Wenku8UrlPolicy.isOfficialPage("https://wenku8.cc/modules/article/toplist.php?sort=allvisit"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("http://www.wenku8.cc/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://wenku8.cc.evil.example/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://user@www.wenku8.cc/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://www.wenku8.cc:444/index.php"))
    }

    @Test
    fun upgradesOnlyLegacyHttpLinksOnTheOfficialHost() {
        assertEquals(
            "https://www.wenku8.cc/login.php?jumpurl=http%3A%2F%2Fwww.wenku8.cc%2Findex.php",
            Wenku8UrlPolicy.httpsUpgradeOfficialPage(
                "http://www.wenku8.cc/login.php?jumpurl=http%3A%2F%2Fwww.wenku8.cc%2Findex.php",
            ),
        )
        assertNull(Wenku8UrlPolicy.httpsUpgradeOfficialPage("http://evil.example/login.php"))
        assertNull(Wenku8UrlPolicy.httpsUpgradeOfficialPage("http://www.wenku8.cc:8080/login.php"))
        assertNull(Wenku8UrlPolicy.httpsUpgradeOfficialPage("http://user@www.wenku8.cc/login.php"))
    }

    @Test
    fun allowsOnlyConfiguredHttpsLoginAndRequestHosts() {
        val base = "https://www.lightnovel.fun/"
        val hosts = listOf("lightnovel.fun", "auth.lightnovel.fun")
        assertTrue(Wenku8UrlPolicy.isAllowedSourcePage(base, base, hosts))
        assertTrue(Wenku8UrlPolicy.isAllowedSourcePage("https://lightnovel.fun/login", base, hosts))
        assertTrue(Wenku8UrlPolicy.isAllowedSourcePage("https://auth.lightnovel.fun/callback", base, hosts))
        assertFalse(Wenku8UrlPolicy.isAllowedSourcePage("https://api.lightnovel.fun/callback", base, hosts))
        assertFalse(Wenku8UrlPolicy.isAllowedSourcePage("http://lightnovel.fun/callback", base, hosts))
        assertFalse(Wenku8UrlPolicy.isAllowedSourcePage("https://lightnovel.fun:444/callback", base, hosts))
        assertFalse(Wenku8UrlPolicy.isAllowedSourcePage("https://user@lightnovel.fun/callback", base, hosts))
        assertFalse(Wenku8UrlPolicy.isAllowedSourcePage("https://lightnovel.fun.evil.example/callback", base, hosts))
    }

    @Test
    fun requestHostsAllowExactApiHostsButNotUnlistedSubdomains() {
        val base = "https://www.example.com/"
        assertTrue(Wenku8UrlPolicy.isAllowedSourceRequest("https://api.example.net/v1/search", base, listOf("api.example.net")))
        assertFalse(Wenku8UrlPolicy.isAllowedSourceRequest("https://evil.api.example.net/v1/search", base, listOf("api.example.net")))
        assertFalse(Wenku8UrlPolicy.isAllowedSourceRequest("http://api.example.net/v1/search", base, listOf("api.example.net")))
    }

    @Test
    fun allowsHttpsCdnSubresourcesButRestrictsTopLevelNavigation() {
        val base = "https://www.lightnovel.fun/"
        val hosts = listOf("lightnovel.fun")
        assertTrue(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://static.lightnovel.fun/assets/app.js", base, hosts, false,
        ))
        assertTrue(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://cdn.example.net/site.css", base, hosts, false,
        ))
        assertFalse(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "http://cdn.example.net/site.css", base, hosts, false,
        ))
        assertTrue(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://www.lightnovel.fun/login", base, hosts, true,
        ))
        assertFalse(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://auth.lightnovel.fun/login", base, hosts, true,
        ))
        assertFalse(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://evil.example/login", base, hosts, true,
        ))
    }

    @Test
    fun allowsHttpsCdnSubresourcesButRestrictsTopLevelNavigation() {
        val base = "https://www.lightnovel.fun/"
        val hosts = listOf("lightnovel.fun")
        assertTrue(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://static.lightnovel.fun/assets/app.js", base, hosts, false,
        ))
        assertTrue(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://cdn.example.net/site.css", base, hosts, false,
        ))
        assertFalse(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "http://cdn.example.net/site.css", base, hosts, false,
        ))
        assertTrue(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://www.lightnovel.fun/login", base, hosts, true,
        ))
        assertFalse(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://auth.lightnovel.fun/login", base, hosts, true,
        ))
        assertFalse(Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
            "https://evil.example/login", base, hosts, true,
        ))
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
        assertTrue(Wenku8UrlPolicy.isAllowedImage("https://www.wenku8.cc/pictures/4/4265/1001/1.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://www.wenku8.cc/book/4265.htm"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://evil.example/image/4/4265/4265s.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/4/4265/4265s.jpg?redirect=evil"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/../secret.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("http://img.wenku8.com/image/4/4265/4265s.jpg"))
    }
}
