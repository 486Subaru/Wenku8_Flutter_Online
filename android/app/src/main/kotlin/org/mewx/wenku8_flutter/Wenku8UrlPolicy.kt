package org.mewx.wenku8_flutter

import java.net.URI

/** Network boundary for the official Wenku8 website and its image hosts. */
internal object Wenku8UrlPolicy {
    private val officialHosts = setOf("www.wenku8.cc", "wenku8.cc")
    private val imageHosts = setOf(
        "img.wenku8.com",
        "pic.wenku8.com",
        "pic.wenku8.cn",
        "pic.wenku8.net",
    )
    private val imagePath = Regex(
        """/(?:image|pictures|illustrations)/[A-Za-z0-9_./-]+\.(?:jpe?g|png|gif|webp)""",
        RegexOption.IGNORE_CASE,
    )

    private fun isAllowedSourceHttpsUrl(raw: String, baseUrl: String, allowedHosts: List<String>): Boolean {
        val uri = parse(raw) ?: return false
        val base = parse(baseUrl) ?: return false
        if (!base.scheme.equals("https", ignoreCase = true) ||
            base.userInfo != null ||
            (base.port != -1 && base.port != 443)) return false
        val validHost = Regex(
            """^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$""",
        )
        val hosts = (allowedHosts.take(12) + listOfNotNull(base.host))
            .map { it.trim().lowercase() }
            .filter { validHost.matches(it) }
            .toSet()
        val path = uri.rawPath
        return uri.scheme.equals("https", ignoreCase = true) &&
            uri.host?.lowercase()?.let { it in hosts } == true &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443) &&
            (path.isNullOrEmpty() || path.startsWith("/"))
    }

    fun isAllowedSourcePage(raw: String, baseUrl: String, allowedHosts: List<String>): Boolean =
        isAllowedSourceHttpsUrl(raw, baseUrl, allowedHosts)

    fun isAllowedSourceRequest(raw: String, baseUrl: String, requestHosts: List<String>): Boolean =
        isAllowedSourceHttpsUrl(raw, baseUrl, requestHosts)

    /** Allow HTTPS CDN resources while keeping top-level navigation host-scoped. */
    fun shouldAllowSourceWebViewRequest(
        raw: String,
        baseUrl: String,
        allowedHosts: List<String>,
        isMainFrame: Boolean,
    ): Boolean {
        val uri = parse(raw) ?: return false
        if (!isMainFrame) {
            return uri.scheme.equals("https", ignoreCase = true) &&
                uri.userInfo == null &&
                (uri.port == -1 || uri.port == 443)
        }
        return isAllowedSourcePage(raw, baseUrl, allowedHosts) || isAllowedChallengeUrl(raw)
    }

    fun isOfficialPage(raw: String): Boolean {
        val uri = parse(raw) ?: return false
        return uri.scheme.equals("https", ignoreCase = true) &&
            uri.host?.lowercase()?.let { it in officialHosts } == true &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443) &&
            uri.rawPath?.startsWith("/") == true
    }

    /**
     * The official site occasionally emits legacy HTTP links. Upgrade only the
     * exact official hosts to HTTPS; never follow an insecure request as-is.
     */
    fun httpsUpgradeOfficialPage(raw: String): String? {
        val uri = parse(raw) ?: return null
        val host = uri.host?.lowercase() ?: return null
        if (!uri.scheme.equals("http", ignoreCase = true) ||
            host !in officialHosts ||
            uri.userInfo != null ||
            (uri.port != -1 && uri.port != 80)
        ) return null

        val path = uri.rawPath?.takeIf { it.isNotEmpty() } ?: "/"
        val query = uri.rawQuery?.let { "?$it" } ?: ""
        val fragment = uri.rawFragment?.let { "#$it" } ?: ""
        return "https://$host$path$query$fragment"
            .takeIf(::isOfficialPage)
    }

    /**
     * Cloudflare's interactive challenge is hosted on this exact origin.
     * Only its challenge/Turnstile paths are allowed; arbitrary Cloudflare
     * pages and all other third-party destinations remain blocked.
     */
    fun isAllowedChallengeUrl(raw: String): Boolean {
        val uri = parse(raw) ?: return false
        val path = uri.rawPath ?: return false
        return uri.scheme.equals("https", ignoreCase = true) &&
            uri.host?.equals("challenges.cloudflare.com", ignoreCase = true) == true &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443) &&
            (path.startsWith("/cdn-cgi/challenge-platform/") ||
                path.startsWith("/turnstile/"))
    }

    fun isAllowedImage(raw: String): Boolean {
        val uri = parse(raw) ?: return false
        val path = uri.rawPath ?: return false
        val host = uri.host?.lowercase()
        val knownImageHost = host in imageHosts && imagePath.matches(path)
        // Some chapter illustrations are served from the official site itself,
        // under these two static paths only. Never allow arbitrary page URLs as images.
        val officialIllustration = host in officialHosts &&
            Regex(
                """^/(?:pictures|illustrations)/[A-Za-z0-9_./-]+\.(?:jpe?g|png|gif|webp)$""",
                RegexOption.IGNORE_CASE,
            ).matches(path)
        return uri.scheme.equals("https", ignoreCase = true) &&
            (knownImageHost || officialIllustration) &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443) &&
            uri.rawQuery == null &&
            uri.rawFragment == null &&
            path.split('/').none { it == ".." }
    }

    private fun parse(raw: String): URI? =
        runCatching { URI(raw.trim()) }.getOrNull()
}
