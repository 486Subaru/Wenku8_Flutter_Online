package org.mewx.wenku8_flutter

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONTokener
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Load an ordinary official-site document in Android's browser engine, using the
 * same per-origin cookie store as the visible login screen. Interactive
 * challenges are returned to the user rather than automated.
 */
internal object Wenku8BrowserPage {
    data class Page(val html: String, val url: String)
    class Failure(val code: String, message: String) : Exception(message)

    fun read(context: Context, url: String, referer: String?, maxBytes: Int, form: ByteArray? = null): Page {
        check(Looper.myLooper() != Looper.getMainLooper())
        if (!Wenku8UrlPolicy.isOfficialPage(url)) {
            throw Failure("WEB_BAD_URL", "网页地址不在允许访问的文库域名内")
        }
        val main = Handler(Looper.getMainLooper())
        val latch = CountDownLatch(1)
        val closed = AtomicBoolean(false)
        val viewRef = AtomicReference<WebView?>(null)
        val page = AtomicReference<Page?>(null)
        val error = AtomicReference<Failure?>(null)

        fun finish(value: Page? = null, failure: Failure? = null) {
            if (!closed.compareAndSet(false, true)) return
            page.set(value)
            error.set(failure)
            main.post {
                viewRef.getAndSet(null)?.let { view ->
                    view.stopLoading()
                    view.destroy()
                }
            }
            latch.countDown()
        }

        main.post {
            if (closed.get()) return@post
            try {
                val view = WebView(context.applicationContext)
                viewRef.set(view)
                view.settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    allowFileAccess = false
                    allowContentAccess = false
                    javaScriptCanOpenWindowsAutomatically = false
                    setSupportMultipleWindows(false)
                    mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                    blockNetworkImage = true
                    cacheMode = WebSettings.LOAD_DEFAULT
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) safeBrowsingEnabled = true
                }
                CookieManager.getInstance().setAcceptCookie(true)
                CookieManager.getInstance().setAcceptThirdPartyCookies(view, false)
                view.webViewClient = object : WebViewClient() {
                    private var httpStatus = 200
                    private var mitigated: String? = null

                    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                        if (!request.isForMainFrame) {
                            return request.url.scheme != "https"
                        }
                        if (Wenku8UrlPolicy.isOfficialPage(request.url.toString())) return false
                        finish(failure = Failure("WEB_REDIRECT_BLOCKED", "官网浏览器请求跳转到非允许的地址"))
                        return true
                    }

                    override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                        httpStatus = 200
                        mitigated = null
                        if (!Wenku8UrlPolicy.isOfficialPage(url.orEmpty())) {
                            finish(failure = Failure("WEB_REDIRECT_BLOCKED", "官网浏览器请求跳转到非允许的地址"))
                        }
                    }

                    override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) {
                        if (!request.isForMainFrame) return
                        httpStatus = response.statusCode
                        mitigated = response.responseHeaders?.entries
                            ?.firstOrNull { it.key.equals("cf-mitigated", ignoreCase = true) }?.value
                    }

                    override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                        if (!request.isForMainFrame) return
                        finish(failure = Failure("WEB_BROWSER_NETWORK", "官网浏览器连接失败，请检查网络后重试"))
                    }

                    override fun onPageFinished(view: WebView, url: String?) {
                        if (closed.get() || url != view.url) return
                        val finalUrl = url ?: return
                        if (!Wenku8UrlPolicy.isOfficialPage(finalUrl)) return
                        view.evaluateJavascript(
                            "document.documentElement ? document.documentElement.outerHTML : ''"
                        ) { encoded ->
                            if (closed.get() || view.url != finalUrl) return@evaluateJavascript
                            val html = runCatching { JSONTokener(encoded).nextValue() as? String }.getOrNull().orEmpty()
                            when {
                                Wenku8RateLimitPolicy.isCloudflareRateLimited(html) ->
                                    finish(failure = Failure("WEB_RATE_LIMITED", "官网 Cloudflare 1015 限流，请等待访问恢复"))
                                httpStatus == 429 ->
                                    finish(failure = Failure("WEB_RATE_LIMITED", "官网拒绝了过于频繁的请求（HTTP 429）"))
                                Wenku8ChallengePolicy.isChallenge(html, mitigated) ->
                                    finish(failure = Failure("WEB_CHALLENGE", "官网仍要求浏览器验证，请在可见官网页面完成验证"))
                                httpStatus == 401 ->
                                    finish(failure = Failure("WEB_LOGIN_REQUIRED", "请先登录轻小说文库账号"))
                                httpStatus == 403 ->
                                    finish(failure = Failure("WEB_BLOCKED", "官网拒绝浏览器请求，请稍后重试"))

                                httpStatus == 404 ->
                                    finish(failure = Failure("WEB_NOT_FOUND", "官网返回 HTTP 404"))
                                httpStatus !in 200..299 ->
                                    finish(failure = Failure("WEB_HTTP_ERROR", "官网浏览器返回 HTTP $httpStatus"))
                                html.isBlank() ->
                                    finish(failure = Failure("WEB_BROWSER_EMPTY", "官网浏览器返回空内容"))
                                html.toByteArray(Charsets.UTF_8).size > maxBytes ->
                                    finish(failure = Failure("WEB_RESPONSE_TOO_LARGE", "官网网页超过大小限制"))
                                else -> finish(Page(html, finalUrl))
                            }
                        }
                    }
                }
                val headers = if (referer != null && Wenku8UrlPolicy.isOfficialPage(referer)) {
                    mapOf("Referer" to referer)
                } else emptyMap()
                if (form == null) view.loadUrl(url, headers)
                else view.postUrl(url, form)
            } catch (_: Exception) {
                finish(failure = Failure("WEB_BROWSER_UNAVAILABLE", "无法启动官网浏览器，请检查 Android System WebView"))
            }
        }
        try {
            if (!latch.await(30, TimeUnit.SECONDS)) {
                finish(failure = Failure("WEB_BROWSER_TIMEOUT", "官网浏览器加载超时，请稍后重试"))
            }
        } catch (_: InterruptedException) {
            finish(failure = Failure("WEB_BROWSER_INTERRUPTED", "官网浏览器请求已取消"))
            Thread.currentThread().interrupt()
        }
        error.get()?.let { throw it }
        return page.get() ?: throw Failure("WEB_BROWSER_EMPTY", "官网浏览器没有返回内容")
    }
}
