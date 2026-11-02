package org.mewx.wenku8_flutter

import android.app.Activity
import android.net.Uri
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

/** A source-specific login surface. WebView cookies remain scoped to that site's host. */
class CustomSourceLoginActivity : Activity() {
    private lateinit var browser: WebView
    private lateinit var status: TextView
    private lateinit var base: Uri
    private lateinit var loginUrl: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val baseRaw = intent.getStringExtra("baseUrl").orEmpty()
        loginUrl = intent.getStringExtra("loginUrl").orEmpty()
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
                    val target = request?.url?.toString() ?: return true
                    if (safePage(target)) return false
                    Toast.makeText(
                        this@CustomSourceLoginActivity,
                        "为隔离账号，只允许访问此书源配置的 HTTPS 域名",
                        Toast.LENGTH_SHORT,
                    ).show()
                    return true
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    status.text = if (!Wenku8SessionCookies.cookieHeader(base.toString()).isNullOrBlank()) {
                        "已检测到此网站的 Cookie。确认登录成功后，点击右上角“完成登录”。"
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

    private fun safePage(raw: String): Boolean {
        val uri = runCatching { Uri.parse(raw) }.getOrNull() ?: return false
        val basePort = if (base.port == -1) 443 else base.port
        val targetPort = if (uri.port == -1) 443 else uri.port
        return uri.scheme == "https" &&
            uri.host?.equals(base.host, ignoreCase = true) == true &&
            targetPort == basePort &&
            uri.userInfo == null
    }

    private fun finishWithError(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        setResult(RESULT_CANCELED)
        finish()
    }

    private fun completeLogin() {
        CookieManager.getInstance().flush()
        if (Wenku8SessionCookies.cookieHeader(base.toString()).isNullOrBlank()) {
            Toast.makeText(this, "尚未检测到此网站的登录 Cookie", Toast.LENGTH_SHORT).show()
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
