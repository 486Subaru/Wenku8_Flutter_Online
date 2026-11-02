package org.mewx.wenku8_flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.webkit.WebSettings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.net.URLDecoder
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction
import java.util.concurrent.Executors
import java.util.zip.GZIPInputStream

/** Direct, rate-limited access to the official website. No third-party relay is used. */
internal class Wenku8OfficialWebPlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private data class Reply(val bytes: ByteArray, val contentType: String?, val finalUrl: String)
    private class WebFailure(val code: String, message: String) : Exception(message)

    companion object {
        private const val CHANNEL = "org.mewx.wenku8/official_web"
        private const val LOGIN_REQUEST = 5081
        private const val SOURCE_LOGIN_REQUEST = 5082
        private const val BASE = "https://www.wenku8.net"
        private const val MAX_TEXT_BYTES = 4 * 1024 * 1024
        private const val MAX_IMAGE_BYTES = 8 * 1024 * 1024
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingLogin: MethodChannel.Result? = null
    private var pendingSourceLogin: MethodChannel.Result? = null
    private var lastRequestAt = 0L
    private var lastSourceRequestAt = 0L
    private var userAgent = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        userAgent = runCatching { WebSettings.getDefaultUserAgent(context) }.getOrDefault(userAgent)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getText" -> {
                val url = call.argument<String>("url") ?: return result.error("WEB_BAD_URL", "缺少网页地址", null)
                val referer = call.argument<String>("referer")
                dispatch(result) { request(url, referer, MAX_TEXT_BYTES, image = false).let { decode(it.bytes, it.contentType) } }
            }
            "getBytes" -> {
                val url = call.argument<String>("url") ?: return result.error("WEB_BAD_URL", "缺少图片地址", null)
                val referer = call.argument<String>("referer")
                dispatch(result) { request(url, referer, MAX_IMAGE_BYTES, image = true).bytes }
            }
            "getSourceText" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("SOURCE_BAD_URL", "缺少书源网页地址", null)
                val baseUrl = call.argument<String>("baseUrl")
                    ?: return result.error("SOURCE_BAD_URL", "缺少书源网站地址", null)
                dispatch(result) {
                    val reply = requestSource(url, baseUrl, emptyList(), MAX_TEXT_BYTES, image = false)
                    decode(reply.bytes, reply.contentType)
                }
            }
            "getSourceBytes" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("SOURCE_BAD_URL", "缺少书源图片地址", null)
                val baseUrl = call.argument<String>("baseUrl")
                    ?: return result.error("SOURCE_BAD_URL", "缺少书源网站地址", null)
                val imageHosts = call.argument<List<String>>("imageHosts")?.take(12) ?: emptyList()
                dispatch(result) {
                    requestSource(url, baseUrl, imageHosts, MAX_IMAGE_BYTES, image = true).bytes
                }
            }
            "postSourceJson" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("SOURCE_BAD_URL", "缺少书源 API 地址", null)
                val baseUrl = call.argument<String>("baseUrl")
                    ?: return result.error("SOURCE_BAD_URL", "缺少书源网站地址", null)
                val body = call.argument<String>("body")
                    ?: return result.error("SOURCE_BAD_BODY", "缺少 API 请求内容", null)
                if (body.length > 256_000) {
                    return result.error("SOURCE_BAD_BODY", "API 请求内容过大", null)
                }
                dispatch(result) {
                    val reply = requestSource(
                        url, baseUrl, emptyList(), MAX_TEXT_BYTES, image = false,
                        method = "POST",
                        requestBody = body.toByteArray(Charsets.UTF_8),
                        contentType = "application/json; charset=UTF-8",
                    )
                    decode(reply.bytes, reply.contentType)
                }
            }
            "searchLightnovel" -> {
                val query = call.argument<String>("query")?.trim().orEmpty()
                val baseUrl = call.argument<String>("baseUrl")
                    ?: return result.error("SOURCE_BAD_URL", "缺少轻之国度网站地址", null)
                val page = call.argument<Int>("page") ?: 1
                if (query.isEmpty() || query.length > 120 || page !in 1..10000) {
                    return result.error("SOURCE_BAD_SEARCH", "轻之国度搜索条件无效", null)
                }
                dispatch(result) { lightNovelSearch(baseUrl, query, page) }
            }
            "search" -> {
                val query = call.argument<String>("query")?.trim().orEmpty()
                val field = call.argument<String>("field") ?: "articlename"
                val page = call.argument<Int>("page") ?: 1
                if (query.isEmpty() || query.length > 120 || field !in setOf("articlename", "author") || page !in 1..100000) {
                    return result.error("WEB_BAD_SEARCH", "搜索条件无效", null)
                }
                val encoded = URLEncoder.encode(query, "GBK")
                val url = BASE + "/modules/article/search.php?searchtype=" + field +
                    "&searchkey=" + encoded + "&page=" + page
                dispatch(result) { decode(request(url, BASE + "/index.php", MAX_TEXT_BYTES, image = false).bytes, "text/html; charset=GB18030") }
            }
            "hasSession" -> result.success(Wenku8SessionCookies.hasSession())
            "openLogin" -> openLogin(result)
            "openSourceLogin" -> {
                val loginUrl = call.argument<String>("loginUrl")
                    ?: return result.error("SOURCE_LOGIN_URL", "缺少书源登录网址", null)
                val baseUrl = call.argument<String>("baseUrl")
                    ?: return result.error("SOURCE_LOGIN_URL", "缺少书源网站地址", null)
                openSourceLogin(loginUrl, baseUrl, result)
            }
            "clearSession" -> dispatch(result) { Wenku8SessionCookies.clear(); null }
            else -> result.notImplemented()
        }
    }

    private fun openLogin(result: MethodChannel.Result) {
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("WEB_NO_ACTIVITY", "当前页面无法打开官网登录窗口", null)
            return
        }
        if (pendingLogin != null) {
            result.error("WEB_LOGIN_BUSY", "官网登录窗口已经打开", null)
            return
        }
        pendingLogin = result
        try {
            activity.startActivityForResult(
                Intent(activity, Wenku8LoginActivity::class.java),
                LOGIN_REQUEST,
            )
        } catch (_: Exception) {
            pendingLogin = null
            result.error("WEB_LOGIN_OPEN_FAILED", "无法打开官网登录页面", null)
        }
    }

    private fun openSourceLogin(loginUrl: String, baseUrl: String, result: MethodChannel.Result) {
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("SOURCE_LOGIN_ACTIVITY", "当前页面无法打开书源登录窗口", null)
            return
        }
        if (pendingSourceLogin != null) {
            result.error("SOURCE_LOGIN_BUSY", "书源登录窗口已经打开", null)
            return
        }
        val base = runCatching { URL(baseUrl) }.getOrNull()
        val login = runCatching { URL(loginUrl) }.getOrNull()
        if (base == null || login == null || !safeHttps(base) || !sameOrigin(login, base)) {
            result.error("SOURCE_LOGIN_URL", "登录网址必须与书源使用同一个 HTTPS 域名", null)
            return
        }
        pendingSourceLogin = result
        try {
            activity.startActivityForResult(
                Intent(activity, CustomSourceLoginActivity::class.java)
                    .putExtra("baseUrl", baseUrl)
                    .putExtra("loginUrl", loginUrl),
                SOURCE_LOGIN_REQUEST,
            )
        } catch (_: Exception) {
            pendingSourceLogin = null
            result.error("SOURCE_LOGIN_OPEN_FAILED", "无法打开书源登录页面", null)
        }
    }

    private fun dispatch(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (failure: WebFailure) {
                main.post { result.error(failure.code, failure.message, null) }
            } catch (_: Exception) {
                main.post { result.error("WEB_NETWORK_ERROR", "网络请求失败，请检查网络后重试", null) }
            }
        }
    }

    private fun request(rawUrl: String, referer: String?, maxBytes: Int, image: Boolean): Reply {
        var current = runCatching { URL(rawUrl) }
            .getOrElse { throw WebFailure("WEB_BAD_URL", "网页地址无效") }
        if (!allowed(current, image)) throw WebFailure("WEB_BAD_URL", "网页地址不在允许访问的文库域名内")

        for (hop in 0..4) {
            waitForRequestSlot()
            val connection = current.openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "GET"
                connection.connectTimeout = 12_000
                connection.readTimeout = 20_000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("User-Agent", userAgent)
                connection.setRequestProperty("Accept-Encoding", "gzip")
                connection.setRequestProperty("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
                connection.setRequestProperty(
                    "Accept",
                    if (image) "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"
                    else "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                )
                if (referer != null && Wenku8UrlPolicy.isOfficialPage(referer)) {
                    connection.setRequestProperty("Referer", referer)
                }
                if (!image && Wenku8UrlPolicy.isOfficialPage(current.toString())) {
                    Wenku8SessionCookies.cookieHeader(current.toString())?.let {
                        connection.setRequestProperty("Cookie", it)
                    }
                }

                val status = connection.responseCode
                val cookies = connection.headerFields.entries
                    .filter { it.key?.equals("Set-Cookie", ignoreCase = true) == true }
                    .flatMap { it.value ?: emptyList() }
                if (!image && cookies.isNotEmpty()) {
                    Wenku8SessionCookies.absorb(current.toString(), cookies)
                }

                if (status in setOf(301, 302, 303, 307, 308)) {
                    val location = connection.getHeaderField("Location")
                        ?: throw WebFailure("WEB_REDIRECT_ERROR", "官网返回了无效跳转")
                    val next = runCatching { URL(current, location) }
                        .getOrElse { throw WebFailure("WEB_REDIRECT_ERROR", "官网返回了无效跳转") }
                    if (!allowed(next, image)) {
                        throw WebFailure("WEB_REDIRECT_BLOCKED", "官网跳转到了非允许域名，已阻止该请求")
                    }
                    current = next
                    continue
                }

                val stream = if (status in 200..299) connection.inputStream
                    else connection.errorStream ?: ByteArrayInputStream(byteArrayOf())
                val raw = stream.use { input ->
                    val decoded = if (connection.contentEncoding?.contains("gzip", ignoreCase = true) == true) {
                        GZIPInputStream(input)
                    } else input
                    readBounded(decoded, maxBytes)
                }
                val contentType = connection.contentType

                if (status == 403) {
                    val body = if (image) "" else decode(raw, contentType)
                    if (isChallenge(body)) throw WebFailure("WEB_CHALLENGE", "官网要求浏览器验证，请先完成官方网页登录验证")
                    throw WebFailure("WEB_BLOCKED", "官网暂时拒绝了请求，请稍后重试")
                }
                if (status == 429) throw WebFailure("WEB_RATE_LIMITED", "请求过于频繁，请稍后重试")
                if (status !in 200..299) throw WebFailure("WEB_HTTP_ERROR", "官网返回 HTTP " + status)

                if (!image) {
                    val body = decode(raw, contentType)
                    if (isChallenge(body)) throw WebFailure("WEB_CHALLENGE", "官网要求浏览器验证，请先完成官方网页登录验证")
                    if (looksLikeLoginPage(body, current)) {
                        throw WebFailure("WEB_LOGIN_REQUIRED", "请先登录轻小说文库账号")
                    }
                }
                return Reply(raw, contentType, current.toString())
            } finally {
                connection.disconnect()
            }
        }
        throw WebFailure("WEB_REDIRECT_ERROR", "官网跳转次数过多")
    }

    private fun requestSource(
        rawUrl: String,
        rawBaseUrl: String,
        imageHosts: List<String>,
        maxBytes: Int,
        image: Boolean,
        method: String = "GET",
        requestBody: ByteArray? = null,
        contentType: String? = null,
    ): Reply {
        val origin = runCatching { URL(rawBaseUrl) }
            .getOrElse { throw WebFailure("SOURCE_BAD_URL", "书源网站地址无效") }
        if (!safeHttps(origin)) {
            throw WebFailure("SOURCE_BAD_URL", "书源网站必须使用 HTTPS")
        }
        val allowedHosts = imageHosts.map { it.trim().lowercase() }
            .filter { it.matches(Regex("^[a-z0-9.-]{1,253}$")) }
            .toSet() + origin.host.lowercase()
        var current = runCatching { URL(rawUrl) }
            .getOrElse { throw WebFailure("SOURCE_BAD_URL", "书源网页地址无效") }
        if (!sourceAllowed(current, origin, allowedHosts, image)) {
            throw WebFailure("SOURCE_BAD_URL", "书源链接超出了配置的网站域名或图片 CDN")
        }

        for (hop in 0..4) {
            waitForSourceRequestSlot()
            val connection = current.openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method
                connection.connectTimeout = 12_000
                connection.readTimeout = 20_000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("User-Agent", userAgent)
                connection.setRequestProperty("Accept-Encoding", "gzip")
                connection.setRequestProperty("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
                connection.setRequestProperty(
                    "Accept",
                    if (image) "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"
                    else if (method == "POST") "application/json, text/plain, */*"
                    else "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                )
                if (sameOrigin(current, origin)) {
                    connection.setRequestProperty("Referer", rawBaseUrl)
                    Wenku8SessionCookies.cookieHeader(current.toString())?.let {
                        connection.setRequestProperty("Cookie", it)
                    }
                }
                if (method == "POST") {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", contentType ?: "application/json; charset=UTF-8")
                    connection.setRequestProperty("X-Requested-With", "XMLHttpRequest")
                    connection.setRequestProperty("Origin", origin.protocol + "://" + origin.host)
                    requestBody?.let { bytes ->
                        connection.outputStream.use { output -> output.write(bytes) }
                    }
                }

                val status = connection.responseCode
                val cookies = connection.headerFields.entries
                    .filter { it.key?.equals("Set-Cookie", ignoreCase = true) == true }
                    .flatMap { it.value ?: emptyList() }
                if (!image && cookies.isNotEmpty() && sameOrigin(current, origin)) {
                    Wenku8SessionCookies.absorbSource(current.toString(), rawBaseUrl, cookies)
                }

                if (status in setOf(301, 302, 303, 307, 308)) {
                    val location = connection.getHeaderField("Location")
                        ?: throw WebFailure("SOURCE_REDIRECT_ERROR", "书源网站返回了无效跳转")
                    val next = runCatching { URL(current, location) }
                        .getOrElse { throw WebFailure("SOURCE_REDIRECT_ERROR", "书源网站返回了无效跳转") }
                    if (!sourceAllowed(next, origin, allowedHosts, image)) {
                        throw WebFailure("SOURCE_REDIRECT_BLOCKED", "书源网站跳转到了未配置的域名，已阻止请求")
                    }
                    current = next
                    continue
                }

                val stream = if (status in 200..299) connection.inputStream
                    else connection.errorStream ?: ByteArrayInputStream(byteArrayOf())
                val raw = stream.use { input ->
                    val decoded = if (connection.contentEncoding?.contains("gzip", ignoreCase = true) == true) {
                        GZIPInputStream(input)
                    } else input
                    readBounded(decoded, maxBytes)
                }
                val contentType = connection.contentType
                if (status == 403) {
                    throw WebFailure("SOURCE_BLOCKED", "书源网站拒绝了请求，可能需要登录或完成网站验证")
                }
                if (status == 429) {
                    throw WebFailure("SOURCE_RATE_LIMITED", "书源网站请求过于频繁，请稍后重试")
                }
                if (status !in 200..299) {
                    throw WebFailure("SOURCE_HTTP_ERROR", "书源网站返回 HTTP " + status)
                }
                if (!image && isChallenge(decode(raw, contentType))) {
                    throw WebFailure("SOURCE_CHALLENGE", "书源网站要求浏览器验证，请检查网站是否允许客户端访问")
                }
                return Reply(raw, contentType, current.toString())
            } finally {
                connection.disconnect()
            }
        }
        throw WebFailure("SOURCE_REDIRECT_ERROR", "书源网站跳转次数过多")
    }

    private fun lightNovelSearch(rawBaseUrl: String, query: String, page: Int): String {
        val origin = runCatching { URL(rawBaseUrl) }
            .getOrElse { throw WebFailure("SOURCE_BAD_URL", "轻之国度网站地址无效") }
        if (!safeHttps(origin) || !origin.host.equals("www.lightnovel.fun", ignoreCase = true)) {
            throw WebFailure("SOURCE_BAD_URL", "轻之国度书源必须使用 https://www.lightnovel.fun/")
        }

        val cookies = Wenku8SessionCookies.cookieHeader(rawBaseUrl).orEmpty()
        val rawToken = cookies.split(';')
            .map { it.trim() }
            .firstOrNull { it.startsWith("token=") }
            ?.substringAfter("token=")
            .orEmpty()
        if (rawToken.isBlank()) {
            throw WebFailure("SOURCE_LOGIN_REQUIRED", "轻之国度搜索需要先登录：请在书源卡片点击“独立登录”")
        }

        var tokenText = rawToken
        var securityKey = ""
        repeat(3) {
            val token = runCatching { JSONObject(tokenText) }.getOrNull()
            if (token != null) {
                securityKey = token.optString("security_key")
                if (securityKey.isNotBlank()) return@repeat
            }
            tokenText = runCatching { URLDecoder.decode(tokenText, "UTF-8") }
                .getOrDefault(tokenText)
        }
        if (securityKey.isBlank()) {
            throw WebFailure("SOURCE_LOGIN_REQUIRED", "没有读取到轻之国度登录凭据，请重新完成网站登录")
        }

        val payload = JSONObject()
            .put("is_encrypted", 0)
            .put("platform", "pc")
            .put("client", "web")
            .put("sign", "")
            .put("gz", 0)
            .put(
                "d",
                JSONObject()
                    .put("q", query)
                    .put("page", page)
                    .put("type", 0)
                    .put("security_key", securityKey),
            )
        val endpoint = URL(origin, "/proxy/api/search/search-result").toString()
        val reply = requestSource(
            endpoint,
            rawBaseUrl,
            emptyList(),
            MAX_TEXT_BYTES,
            image = false,
            method = "POST",
            requestBody = payload.toString().toByteArray(Charsets.UTF_8),
            contentType = "application/json; charset=UTF-8",
        )
        return decode(reply.bytes, reply.contentType)
    }

    private fun safeHttps(url: URL): Boolean =
        url.protocol.equals("https", ignoreCase = true) &&
            url.host.isNotBlank() &&
            url.userInfo == null &&
            (url.port == -1 || url.port == 443)

    private fun sameOrigin(a: URL, b: URL): Boolean =
        a.protocol.equals(b.protocol, ignoreCase = true) &&
            a.host.equals(b.host, ignoreCase = true) &&
            (if (a.port == -1) 443 else a.port) ==
                (if (b.port == -1) 443 else b.port)

    private fun sourceAllowed(
        url: URL,
        origin: URL,
        allowedHosts: Set<String>,
        image: Boolean,
    ): Boolean {
        if (!safeHttps(url)) return false
        return if (image) {
            val host = url.host.lowercase()
            allowedHosts.any { allowed ->
                host == allowed || host.endsWith(".$allowed")
            }
        } else {
            sameOrigin(url, origin)
        }
    }

    private fun waitForSourceRequestSlot() {
        val now = SystemClock.elapsedRealtime()
        val delay = 500L - (now - lastSourceRequestAt)
        if (lastSourceRequestAt != 0L && delay > 0) Thread.sleep(delay)
        lastSourceRequestAt = SystemClock.elapsedRealtime()
    }

    private fun allowed(url: URL, image: Boolean): Boolean =
        if (image) Wenku8UrlPolicy.isAllowedImage(url.toString())
        else Wenku8UrlPolicy.isOfficialPage(url.toString())

    private fun waitForRequestSlot() {
        val now = SystemClock.elapsedRealtime()
        val delay = 900L - (now - lastRequestAt)
        if (lastRequestAt != 0L && delay > 0) Thread.sleep(delay)
        lastRequestAt = SystemClock.elapsedRealtime()
    }

    private fun readBounded(input: java.io.InputStream, limit: Int): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (output.size() + count > limit) {
                throw WebFailure("WEB_RESPONSE_TOO_LARGE", "官网返回内容超过大小限制")
            }
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private fun decode(bytes: ByteArray, contentType: String?): String {
        if (bytes.isEmpty()) return ""
        val declared = Regex("""(?i)charset\s*=\s*["']?([^;"'\s]+)""")
            .find(contentType.orEmpty())?.groupValues?.get(1)
        val head = String(bytes, 0, minOf(bytes.size, 4096), Charsets.ISO_8859_1)
        val meta = Regex("""(?i)charset\s*=\s*["']?([A-Za-z0-9_-]+)""")
            .find(head)?.groupValues?.get(1)
        val candidates = listOfNotNull(declared, meta, "UTF-8", "GB18030").distinct()
        for (name in candidates) {
            val charset = runCatching { Charset.forName(name.trim().trim('"', '\'')) }.getOrNull() ?: continue
            val decoded = runCatching {
                charset.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes))
                    .toString()
            }.getOrNull()
            if (decoded != null) return decoded
        }
        return String(bytes, Charset.forName("GB18030"))
    }

    private fun isChallenge(body: String): Boolean {
        val text = body.lowercase()
        return text.contains("cf-chl-") ||
            text.contains("challenge-platform") ||
            text.contains("just a moment") ||
            text.contains("checking your browser") ||
            text.contains("attention required")
    }

    private fun looksLikeLoginPage(body: String, url: URL): Boolean {
        if (url.path.endsWith("/login.php", ignoreCase = true)) return true
        val text = body.lowercase()
        return text.contains("用户登录") &&
            (text.contains("name=\"password\"") || text.contains("name='password'"))
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        pendingLogin?.let {
            main.post { it.error("WEB_NO_ACTIVITY", "登录窗口已关闭", null) }
        }
        pendingLogin = null
        pendingSourceLogin?.let {
            main.post { it.error("SOURCE_LOGIN_ACTIVITY", "书源登录窗口已关闭", null) }
        }
        pendingSourceLogin = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == LOGIN_REQUEST) {
            val callback = pendingLogin
            pendingLogin = null
            callback?.success(resultCode == Activity.RESULT_OK && Wenku8SessionCookies.hasSession())
            return true
        }
        if (requestCode == SOURCE_LOGIN_REQUEST) {
            val callback = pendingSourceLogin
            pendingSourceLogin = null
            // The dedicated login activity verifies cookies against the actual
            // current/login URL so path-scoped cookies are not mistaken for failure.
            callback?.success(resultCode == Activity.RESULT_OK)
            return true
        }
        return false
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        worker.shutdownNow()
        detachActivity()
    }

}
