package org.mewx.wenku8_flutter

import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Cookies stay inside Android WebView storage; they are never exposed to Dart. */
internal object Wenku8SessionCookies {
    private const val ORIGIN = "https://www.wenku8.net/"
    private val main = Handler(Looper.getMainLooper())

    fun hasSession(): Boolean {
        val values = parse(cookieHeader(ORIGIN).orEmpty())
        return !values["PHPSESSID"].isNullOrBlank() &&
            !values["jieqiUserInfo"].isNullOrBlank()
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

    /** Remove only Wenku8 cookies, leaving cookies for every other site intact. */
    fun clear() {
        val names = parse(cookieHeader(ORIGIN).orEmpty()).keys
        val deletions = mutableListOf<String>()
        for (name in names) {
            deletions.add(name + "=; Max-Age=0; Path=/")
            deletions.add(name + "=; Max-Age=0; Path=/; Domain=www.wenku8.net")
            deletions.add(name + "=; Max-Age=0; Path=/; Domain=wenku8.net")
        }
        if (deletions.isNotEmpty()) setCookies(ORIGIN, deletions)
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
