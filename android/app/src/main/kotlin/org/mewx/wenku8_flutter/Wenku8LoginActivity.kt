package org.mewx.wenku8_flutter

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/** Official-site login surface so the user can complete any site challenge themselves. */
class Wenku8LoginActivity : Activity() {
    private lateinit var browser: WebView
    private lateinit var status: TextView
    private var blockedNavigationHost: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
            text = "日轻 · 文库账号登录"
            textSize = 16f
            gravity = Gravity.CENTER_VERTICAL
            setPadding(8, 0, 8, 0)
        }
        val done = Button(this).apply {
            text = "完成登录"
            setOnClickListener { completeLogin() }
        }
        toolbar.addView(back, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))
        toolbar.addView(title, LinearLayout.LayoutParams(
            0,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            1f,
        ))
        toolbar.addView(done, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        status = TextView(this).apply {
            text = "请在文库官网首页选择登录或注册；如出现网站验证，请按页面提示完成。"
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
                    val uri = request?.url ?: return false
                    val target = uri.toString()
                    if (Wenku8UrlPolicy.isOfficialPage(target) ||
                        Wenku8UrlPolicy.isAllowedChallengeUrl(target)
                    ) return false

                    // The site still contains some HTTP links. Upgrade those
                    // exact official-host URLs instead of allowing cleartext.
                    val upgraded = Wenku8UrlPolicy.httpsUpgradeOfficialPage(target)
                    if (upgraded != null) {
                        view?.loadUrl(upgraded)
                        return true
                    }

                    // Third-party subframes are blocked quietly. The one
                    // required Cloudflare verification origin is allowlisted
                    // above, so analytics/ads cannot repeatedly toast over login.
                    if (!request.isForMainFrame) return true

                    val host = uri.host ?: uri.scheme ?: "未知地址"
                    blockedNavigationHost = host
                    status.text = "已拦截站外跳转（" + host + "）。为保护账号，仅允许文库官网及其验证页面。"
                    Toast.makeText(
                        this@Wenku8LoginActivity,
                        "为保护账号，已拦截非文库页面：" + host,
                        Toast.LENGTH_SHORT,
                    ).show()
                    return true
                }

                override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                    super.onPageStarted(view, url, favicon)
                    blockedNavigationHost = null
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    status.text = when {
                        Wenku8SessionCookies.hasSession() ->
                            "已检测到官网登录状态，点击右上角“完成登录”返回应用。"
                        blockedNavigationHost != null ->
                            "已拦截站外跳转（" + blockedNavigationHost + "）。请返回文库官网继续登录。"
                        else ->
                            "请在官网页面点击登录或注册；如出现网站验证，请按页面提示完成。"
                    }
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: android.webkit.WebResourceError?,
                ) {
                    super.onReceivedError(view, request, error)
                    if (request?.isForMainFrame == true) {
                        status.text = "文库页面加载失败（" + (error?.errorCode ?: "未知") + "）。请检查网络后重试。"
                    }
                }

                override fun onReceivedHttpError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    errorResponse: android.webkit.WebResourceResponse?,
                ) {
                    super.onReceivedHttpError(view, request, errorResponse)
                    if (request?.isForMainFrame == true) {
                        status.text = "文库官网返回 HTTP " + (errorResponse?.statusCode ?: "错误") + "。请稍后重试。"
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
        browser.loadUrl("https://www.wenku8.cc/index.php")
    }

    private fun completeLogin() {
        CookieManager.getInstance().flush()
        if (!Wenku8SessionCookies.hasSession()) {
            Toast.makeText(this, "尚未检测到有效的文库登录状态", Toast.LENGTH_SHORT).show()
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
