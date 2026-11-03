package org.mewx.wenku8_flutter

import android.app.Activity
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/** A source-specific login surface. WebView cookies remain scoped to that site's host. */
class CustomSourceLoginActivity : Activity() {
    private lateinit var browser: WebView
    private lateinit var status: TextView
    private lateinit var base: Uri
    private lateinit var loginUrl: String
    private var allowedHosts: List<String> = emptyList()
    private var pageError: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val baseRaw = intent.getStringExtra("baseUrl").orEmpty()
        loginUrl = intent.getStringExtra("loginUrl").orEmpty()
        allowedHosts = intent.getStringArrayListExtra("allowedHosts")?.toList().orEmpty()
        base = runCatching { Uri.parse(baseRaw) }.getOrNull()
            ?: return finishWithError("书源网站地址无效")
        if (!safePage(loginUrl)) return finishWithError("登录网址必须属于配置的 HTTPS 网站")

        CookieManager.getInstance().setAcceptCookie(true)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(12, 8, 12, 8)
        }
        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val back = Button(this).apply {
            text = "返回"
            setOnClickListener {
                setResult(RESULT_CANCELED)
                finish()
            }
        }
        val title = TextView(this).apply {
            text = "书源网站 · 独立登录"
            textSize = 16f
            gravity = Gravity.CENTER_VERTICAL
            setPadding(8, 0, 8, 0)
        }
        val done = Button(this).apply {
            text = "完成登录"
            setOnClickListener { completeLogin() }
        }
        toolbar.addView(back)
        toolbar.addView(title, LinearLayout.LayoutParams(
            0,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            1f,
        ))
        val reload = Button(this).apply {
            text = "重试"
            setOnClickListener {
                pageError = null
                status.text = "正在重新加载网站…"
                browser.reload()
            }
        }
        toolbar.addView(reload)
        toolbar.addView(done)

        status = TextView(this).apply {
            text = "请在下方网站页面登录。此站 Cookie 与轻小说文库主站分开保存。"
            textSize = 13f
            setPadding(8, 6, 8, 10)
        }
        browser = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.javaScriptCanOpenWindowsAutomatically = false
            settings.setSupportMultipleWindows(false)
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                settings.safeBrowsingEnabled = true
            }
            CookieManager.getInstance().setAcceptThirdPartyCookies(this, false)
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?,
                ): Boolean {
                    val navigation = request ?: return true
                    val target = navigation.url.toString()
                    if (Wenku8UrlPolicy.shouldAllowSourceWebViewRequest(
                            target,
                            base.toString(),
                            allowedHosts,
                            navigation.isForMainFrame,
                        )) return false
                    // Only top-level redirects need a visible allowlist error.
                    if (!navigation.isForMainFrame) return true
                    val blockedHost = navigation.url.host ?: "未知域名"
                    pageError = "已拦截未配置的登录跳转域名：$blockedHost。请在书源设置的“登录跳转域名白名单”中添加该 HTTPS 主机名后重试。"
                    status.text = pageError
                    Toast.makeText(
                        this@CustomSourceLoginActivity,
                        "登录跳转域名未加入白名单：$blockedHost",
                        Toast.LENGTH_LONG,
                    ).show()
                    return true
                }

                override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                    super.onPageStarted(view, url, favicon)
                    pageError = null
                    status.text = "正在加载网站页面…"
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: WebResourceError?,
                ) {
                    super.onReceivedError(view, request, error)
                    if (request?.isForMainFrame == true) {
                        pageError = "网页加载失败：${error?.description ?: "网络连接异常"}。请检查网络和代理分流，然后点击“重试”。"
                        status.text = pageError
                    }
                }

                override fun onReceivedHttpError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    errorResponse: WebResourceResponse?,
                ) {
                    super.onReceivedHttpError(view, request, errorResponse)
                    if (request?.isForMainFrame == true) {
                        val code = errorResponse?.statusCode ?: 0
                        pageError = "网站返回 HTTP $code。若为 403，可能需要完成网站验证；若为 429，请稍后重试。"
                        status.text = pageError
                    }
                }

                override fun onReceivedSslError(
                    view: WebView?,
                    handler: SslErrorHandler?,
                    error: android.net.http.SslError?,
                ) {
                    handler?.cancel()
                    val failedUrl = error?.url
                    if (!failedUrl.isNullOrBlank() && failedUrl == view?.url) {
                        pageError = "HTTPS 证书验证失败，已安全停止加载。请检查系统时间、网络或网站证书。"
                        status.text = pageError
                    }
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    if (pageError != null) return
                    val isLightNovel = base.host.equals("www.lightnovel.fun", ignoreCase = true) ||
                        base.host.equals("lightnovel.fun", ignoreCase = true)
                    status.text = if (isLightNovel) {
                        "轻之国度公开书籍无需登录即可用于主页和搜索；网站账号登录仅用于账号相关功能。"
                    } else if (hasSourceCookie(url)) {
                        "已检测到此网站的登录凭据。确认登录成功后，点击右上角“完成登录”。"
                    } else {
                        "请在下方网站页面登录；账号与主站分开保存。"
                    }
                }
            }
        }
        root.addView(toolbar)
        root.addView(status)
        root.addView(browser, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))
        setContentView(root)
        browser.loadUrl(loginUrl)
    }

    private fun safePage(raw: String): Boolean =
        Wenku8UrlPolicy.isAllowedSourcePage(raw, base.toString(), allowedHosts)

    private fun hasSourceCookie(currentUrl: String?): Boolean {
        if (base.host.equals("www.lightnovel.fun", ignoreCase = true) ||
            base.host.equals("lightnovel.fun", ignoreCase = true)) {
            // The token may be scoped to /proxy and set on either exact site host.
            val hosts = linkedSetOf(base.host, "www.lightnovel.fun", "lightnovel.fun")
            return hosts.any { host ->
                val apiUrl = "https://$host/proxy/api/search/search-result"
                LightNovelTokenParser.fromCookieHeader(
                    CookieManager.getInstance().getCookie(apiUrl),
                ) != null
            }
        }
        val candidates = listOfNotNull(currentUrl, loginUrl, base.toString()).distinct()
        return candidates.any { !Wenku8SessionCookies.cookieHeader(it).isNullOrBlank() }
    }

    private fun finishWithError(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        setResult(RESULT_CANCELED)
        finish()
    }

    private fun completeLogin() {
        CookieManager.getInstance().flush()
        val isLightNovel = base.host.equals("www.lightnovel.fun", ignoreCase = true) ||
            base.host.equals("lightnovel.fun", ignoreCase = true)
        if (isLightNovel) {
            // Current lightnovel.fun stores security_key in localStorage. Read
            // only enough to verify that the user really completed website login;
            // the value is never passed to Dart and public reading does not need it.
            val script = """
                (function() {
                  try {
                    var re = /[a-f0-9]{16,}:\d+:\d+/i;
                    for (var i = 0; i < localStorage.length; i++) {
                      var v = localStorage.getItem(localStorage.key(i)) || '';
                      var m = v.match(re);
                      if (m) return m[0];
                    }
                  } catch (e) {}
                  return '';
                })()
            """.trimIndent()
            browser.evaluateJavascript(script) { value ->
                val found = !value.isNullOrBlank() && value != "null" && value != "\"\""
                if (!found) {
                    Toast.makeText(
                        this,
                        "未检测到网站账号登录状态；公开书籍无需登录即可用于主页和搜索",
                        Toast.LENGTH_LONG,
                    ).show()
                    return@evaluateJavascript
                }
                setResult(RESULT_OK)
                finish()
            }
            return
        }
        if (!hasSourceCookie(browser.url)) {
            Toast.makeText(this, "尚未检测到此网站的登录凭据；请先完成登录", Toast.LENGTH_SHORT).show()
            return
        }
        setResult(RESULT_OK)
        finish()
    }

    @Deprecated("Use the system back gesture or the visible back button")
    override fun onBackPressed() {
        if (::browser.isInitialized && browser.canGoBack()) {
            browser.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        if (::browser.isInitialized) {
            browser.stopLoading()
            browser.webChromeClient = null
            browser.destroy()
        }
        super.onDestroy()
    }
}
