package org.mewx.wenku8_flutter

import android.webkit.CookieManager
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Cookies stay inside Android WebView storage; they are never exposed to Dart. */
internal object Wenku8SessionCookies {
    private const val ORIGIN = "https://www.wenku8.net/"

    fun hasSession(): Boolean {
        val values = parse(CookieManager.getInstance().getCookie(ORIGIN).orEmpty())
        return !values["PHPSESSID"].isNullOrBlank() &&
            !values["jieqiUserInfo"].isNullOrBlank()
    }

    fun absorb(url: String, headers: List<String>) {
        if (!Wenku8UrlPolicy.isOfficialPage(url)) return
        val manager = CookieManager.getInstance()
        for (header in headers) {
            val latch = CountDownLatch(1)
            manager.setCookie(url, header) { latch.countDown() }
            latch.await(2, TimeUnit.SECONDS)
        }
        manager.flush()
    }

    /** Remove only Wenku8 cookies, leaving cookies for every other site intact. */
    fun clear() {
        val manager = CookieManager.getInstance()
        val names = parse(manager.getCookie(ORIGIN).orEmpty()).keys
        for (name in names) {
            setAndWait(manager, ORIGIN, name + "=; Max-Age=0; Path=/")
            setAndWait(manager, ORIGIN, name + "=; Max-Age=0; Path=/; Domain=www.wenku8.net")
            setAndWait(manager, ORIGIN, name + "=; Max-Age=0; Path=/; Domain=wenku8.net")
        }
        manager.flush()
    }

    private fun setAndWait(manager: CookieManager, url: String, value: String) {
        val latch = CountDownLatch(1)
        manager.setCookie(url, value) { latch.countDown() }
        latch.await(2, TimeUnit.SECONDS)
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
