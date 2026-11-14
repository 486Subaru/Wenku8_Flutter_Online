package org.mewx.wenku8_flutter

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Cookies stay inside Android WebView storage; they are never exposed to Dart. */
internal object Wenku8SessionCookies {
    private const val ORIGIN = "https://www.wenku8.net/"
    private val origins = listOf(ORIGIN, "https://wenku8.net/", "https://www.wenku8.cc/", "https://wenku8.cc/")
    private val main = Handler(Looper.getMainLooper())
    private var preferences: SharedPreferences? = null

    fun initialize(context: Context) {
        preferences = context.applicationContext.getSharedPreferences("wenku8_official_session", Context.MODE_PRIVATE)
    }

    private fun originOf(url: String?): String? {
        if (url == null || !Wenku8UrlPolicy.isOfficialPage(url)) return null
        val host = runCatching { java.net.URI(url).host?.lowercase() }.getOrNull()
        return origins.firstOrNull { it == "https://$host/" }
    }

    private fun hasSessionAt(origin: String): Boolean {
        val values = parse(cookieHeader(origin).orEmpty())
        return !values["PHPSESSID"].isNullOrBlank() &&
            !values["jieqiUserInfo"].isNullOrBlank()
    }

    fun activeOrigin(): String {
        val saved = preferences?.getString("last_verified_origin", null)
        if (saved in origins && saved != null && hasSessionAt(saved)) return saved
        return origins.firstOrNull(::hasSessionAt) ?: ORIGIN
    }

    fun hasSession(): Boolean = origins.any(::hasSessionAt)

    /** Record the actual official origin on which the user completed login. */
    fun rememberLoginOrigin(url: String?): Boolean {
        val origin = originOf(url) ?: return false
        if (!hasSessionAt(origin)) return false
        preferences?.edit()?.putString("last_verified_origin", origin)?.apply()
        return true
    }

    fun routeOfficialPage(raw: String): String {
        if (!Wenku8UrlPolicy.isOfficialPage(raw)) return raw
        val uri = java.net.URI(raw)
        val origin = activeOrigin().trimEnd('/')
        return origin + uri.rawPath +
            (uri.rawQuery?.let { "?$it" } ?: "") +
            (uri.rawFragment?.let { "#$it" } ?: "")
    }

    fun cookieHeader(url: String): String? {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return CookieManager.getInstance().getCookie(url)
        }
        val result = AtomicReference<String?>()
        val latch = CountDownLatch(1)
        main.post {
            try {
                result.set(CookieManager.getInstance().getCookie(url))
            } finally {
                latch.countDown()
            }
        }
        if (!latch.await(3, TimeUnit.SECONDS)) {
            throw IllegalStateException("Cookie read timed out")
        }
        return result.get()
    }

    fun absorb(url: String, headers: List<String>) {
        if (!Wenku8UrlPolicy.isOfficialPage(url) || headers.isEmpty()) return
        setCookies(url, headers)
        flush()
    }

    /** Keep cookies for a user-configured source scoped to its exact HTTPS origin. */
    fun absorbSource(
        url: String,
        baseUrl: String,
        allowedHosts: List<String>,
        headers: List<String>,
    ) {
        val target = runCatching { java.net.URI(url) }.getOrNull() ?: return
        val base = runCatching { java.net.URI(baseUrl) }.getOrNull() ?: return
        val hosts = (allowedHosts + listOfNotNull(base.host))
            .map { it.trim().lowercase() }
            .toSet()
        if (headers.isEmpty() ||
            target.scheme != "https" ||
            base.scheme != "https" ||
            target.userInfo != null ||
            base.userInfo != null ||
            target.host?.lowercase()?.let { it in hosts } != true ||
            (if (target.port == -1) 443 else target.port) != 443 ||
            (if (base.port == -1) 443 else base.port) != 443) return
        setCookies(url, headers)
        flush()
    }

    /** Remove only Wenku8 cookies, leaving cookies for every other site intact. */
    fun clear() {
        for (origin in origins) {
            val names = parse(cookieHeader(origin).orEmpty()).keys
            val host = java.net.URI(origin).host
            val domain = host.removePrefix("www.")
            val deletions = names.flatMap { name ->
                listOf(
                    "$name=; Max-Age=0; Path=/",
                    "$name=; Max-Age=0; Path=/; Domain=$host",
                    "$name=; Max-Age=0; Path=/; Domain=$domain",
                )
            }
            if (deletions.isNotEmpty()) setCookies(origin, deletions)
        }
        preferences?.edit()?.remove("last_verified_origin")?.apply()
        flush()
    }

    private fun setCookies(url: String, values: List<String>) {
        val latch = CountDownLatch(values.size)
        main.post {
            val manager = CookieManager.getInstance()
            for (value in values) {
                manager.setCookie(url, value) { latch.countDown() }
            }
        }
        if (!latch.await(4, TimeUnit.SECONDS)) {
            throw IllegalStateException("Cookie update timed out")
        }
    }

    private fun flush() {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            CookieManager.getInstance().flush()
            return
        }
        val latch = CountDownLatch(1)
        main.post {
            try {
                CookieManager.getInstance().flush()
            } finally {
                latch.countDown()
            }
        }
        if (!latch.await(3, TimeUnit.SECONDS)) {
            throw IllegalStateException("Cookie flush timed out")
        }
    }

    private fun parse(raw: String): Map<String, String> {
        val values = linkedMapOf<String, String>()
        for (part in raw.split(';')) {
            val item = part.trim()
            val separator = item.indexOf('=')
            if (separator <= 0) continue
            val name = item.substring(0, separator).trim()
            val value = item.substring(separator + 1).trim()
            if (name.isNotEmpty()) values[name] = value
        }
        return values
    }
}
