package org.mewx.wenku8_flutter

import java.net.URI

/** Network boundary for the official Wenku8 website and its image hosts. */
internal object Wenku8UrlPolicy {
    private val officialHosts = setOf("www.wenku8.net", "wenku8.net")
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

    fun isOfficialPage(raw: String): Boolean {
        val uri = parse(raw) ?: return false
        return uri.scheme.equals("https", ignoreCase = true) &&
            uri.host?.lowercase()?.let { it in officialHosts } == true &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443) &&
            uri.rawPath?.startsWith("/") == true
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
