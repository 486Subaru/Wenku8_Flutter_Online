from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one match, found {count}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))


def replace_all(path: str, old: str, new: str, minimum: int = 1) -> None:
    text = read(path)
    count = text.count(old)
    if count < minimum:
        raise RuntimeError(f"{path}: expected at least {minimum} matches, found {count}: {old!r}")
    write(path, text.replace(old, new))


# 1) Make the saved built-in source migration execute before repositories are built.
replace_once(
    "lib/main.dart",
    "import 'book_sources.dart';\n",
    "import 'book_sources.dart';\nimport 'built_in_source_upgrades.dart';\n",
)
replace_once(
    "lib/main.dart",
    """  try {\n    await bookSources.load();\n  } catch (_) {\n    // A damaged optional source list must never prevent opening the library.\n  }\n  BookSourceStore.instance = bookSources;\n""",
    """  try {\n    await bookSources.load();\n  } catch (_) {\n    // A damaged optional source list must never prevent opening the library.\n  }\n  try {\n    await upgradeBuiltInSourceCompatibility(bookSources);\n  } catch (_) {\n    // A built-in compatibility migration must never prevent app startup.\n  }\n  BookSourceStore.instance = bookSources;\n""",
)

# 2) Built-in presets: Linovel becomes a real reader source; Bilinovel follows its
# current first-party domain migration chain instead of requiring hand-edited hosts.
old_bilinovel = """    BookSourceConfig(\n      id: 'linovelib-web',\n      name: '哔哩轻小说',\n      baseUrl: 'https://www.linovelib.com/',\n      engine: 'web_login_only',\n      enabled: false,\n      loginUrl: '/login.php',\n      searchUrlTemplate: '',\n      searchItemSelector: '',\n      searchTitleSelector: '',\n      chapterItemSelector: '',\n      chapterContentSelector: '',\n    ),\n"""
new_bilinovel = """    BookSourceConfig(\n      id: 'linovelib-web',\n      name: '哔哩轻小说',\n      baseUrl: 'https://www.bilinovel.net/',\n      engine: 'web_login_only',\n      enabled: false,\n      loginUrl: '/login.php',\n      loginHosts: [\n        'bilinovel.net',\n        'www.bilinovel.com',\n        'bilinovel.com',\n        'www.linovelib.com',\n        'linovelib.com',\n      ],\n      requestHosts: [\n        'bilinovel.net',\n        'www.bilinovel.com',\n        'bilinovel.com',\n        'www.linovelib.com',\n        'linovelib.com',\n      ],\n      searchUrlTemplate: '',\n      searchItemSelector: '',\n      searchTitleSelector: '',\n      chapterItemSelector: '',\n      chapterContentSelector: '',\n    ),\n"""
replace_once("lib/book_sources.dart", old_bilinovel, new_bilinovel)

old_linovel = """    BookSourceConfig(\n      id: 'linovel-net-web',\n      name: '轻之文库',\n      baseUrl: 'https://www.linovel.net/',\n      engine: 'web_login_only',\n      enabled: false,\n      loginUrl: '/auth/login',\n      searchUrlTemplate: '',\n      searchItemSelector: '',\n      searchTitleSelector: '',\n      chapterItemSelector: '',\n      chapterContentSelector: '',\n    ),\n"""
new_linovel = """    BookSourceConfig(\n      id: 'linovel-net-web',\n      name: '轻之文库',\n      baseUrl: 'https://www.linovel.net/',\n      engine: 'css',\n      enabled: true,\n      loginUrl: '/auth/login',\n      loginHosts: ['linovel.net'],\n      requestHosts: ['linovel.net'],\n      browseUrlTemplate: '/cat/-1.html?sort=hot&sign=-1&page={page}',\n      searchUrlTemplate: '/search/?kw={keyword}&page={page}',\n      searchItemSelector: '.search-book, .book-draw',\n      searchTitleSelector: '.book-name',\n      searchAuthorSelector: '.book-extra',\n      searchGenreSelector: '.book-tag',\n      searchSummarySelector: '.book-intro',\n      searchCoverSelector: '.book-cover img',\n      searchCoverAttribute: 'src',\n      detailTitleSelector: '.book-title',\n      detailAuthorSelector: '.novelist > .name > a',\n      detailSummarySelector: '.about-text',\n      detailGenreSelector: '.book-cats',\n      detailStatusSelector: '.book-data > span:nth-child(7)',\n      detailCoverSelector: '.book-cover img',\n      detailCoverAttribute: 'src',\n      chapterItemSelector: '.section-list .chapter',\n      chapterTitleSelector: 'a',\n      chapterHrefSelector: 'a',\n      chapterContentSelector: '.article-text > p',\n      imageHosts: ['linovel.net'],\n    ),\n"""
replace_once("lib/book_sources.dart", old_linovel, new_linovel)
replace_once(
    "lib/book_sources.dart",
    "  /// Built-in site shortcuts. Only the Light Novel Kingdom preset currently\n  /// has a native reader adapter; the others are isolated WebView login entries.\n",
    "  /// Built-in site shortcuts. Light Novel Kingdom uses its API adapter and\n  /// Linovel uses the generic CSS reader; login-only entries stay isolated.\n",
)

# 3) Wenku8 moved its canonical site to .net. Keep .cc as a legacy alias in the
# policy so old links/caches survive, but all new requests and login use .net.
replace_once(
    "android/app/src/main/kotlin/org/mewx/wenku8_flutter/Wenku8UrlPolicy.kt",
    '    private val officialHosts = setOf("www.wenku8.cc", "wenku8.cc")',
    '    private val officialHosts = setOf("www.wenku8.net", "wenku8.net", "www.wenku8.cc", "wenku8.cc")',
)
replace_once(
    "android/app/src/main/kotlin/org/mewx/wenku8_flutter/Wenku8OfficialWebPlugin.kt",
    '        private const val BASE = "https://www.wenku8.cc"',
    '        private const val BASE = "https://www.wenku8.net"',
)
replace_once(
    "android/app/src/main/kotlin/org/mewx/wenku8_flutter/Wenku8LoginActivity.kt",
    '        browser.loadUrl("https://www.wenku8.cc/index.php")',
    '        browser.loadUrl("https://www.wenku8.net/index.php")',
)
replace_once(
    "android/app/src/main/kotlin/org/mewx/wenku8_flutter/Wenku8SessionCookies.kt",
    '    private const val ORIGIN = "https://www.wenku8.cc/"',
    '    private const val ORIGIN = "https://www.wenku8.net/"',
)
replace_once(
    "android/app/src/main/kotlin/org/mewx/wenku8_flutter/Wenku8SessionCookies.kt",
    '            deletions.add(name + "=; Max-Age=0; Path=/; Domain=www.wenku8.cc")\n            deletions.add(name + "=; Max-Age=0; Path=/; Domain=wenku8.cc")',
    '            deletions.add(name + "=; Max-Age=0; Path=/; Domain=www.wenku8.net")\n            deletions.add(name + "=; Max-Age=0; Path=/; Domain=wenku8.net")\n            deletions.add(name + "=; Max-Age=0; Path=/; Domain=www.wenku8.cc")\n            deletions.add(name + "=; Max-Age=0; Path=/; Domain=wenku8.cc")',
)
replace_once(
    "lib/wenku8_html_parser.dart",
    "  static const base = 'https://www.wenku8.cc/';",
    "  static const base = 'https://www.wenku8.net/';",
)
replace_all("lib/book_source_settings_page.dart", "www.wenku8.cc", "www.wenku8.net", minimum=2)

# 4) Light Novel Kingdom 2026: public reading/search no longer depends on the
# legacy token cookie. Use the current PC-proxy BFF search for both Search and
# Discover and normalize it to the Dart adapter's existing result shape.
plugin_path = "android/app/src/main/kotlin/org/mewx/wenku8_flutter/Wenku8OfficialWebPlugin.kt"
plugin = read(plugin_path)
start = plugin.index("    private fun lightNovelSession(")
end = plugin.index("    private fun safeHttps(", start)
new_lightnovel = r'''    private fun lightNovelSearch(rawBaseUrl: String, query: String, page: Int, requestHosts: List<String>): String {
        val origin = runCatching { URL(rawBaseUrl) }
            .getOrElse { throw WebFailure("SOURCE_BAD_URL", "轻之国度网站地址无效") }
        val siteHosts = setOf("www.lightnovel.fun", "lightnovel.fun")
        if (!safeHttps(origin) || origin.host.lowercase() !in siteHosts) {
            throw WebFailure("SOURCE_BAD_URL", "轻之国度书源必须使用 HTTPS 官方域名")
        }

        // The current PC proxy accepts credential-free reads. The BFF endpoint
        // replaced the legacy search-result endpoint in 2026. Page is zero-based
        // on this endpoint while the Flutter repository is one-based.
        val payload = JSONObject()
            .put("q", query)
            .put("page", maxOf(0, page - 1))
            .put("pageSize", 20)
            .put("sort", if (query.isBlank()) "new" else "relevance")
        if (query.isBlank()) payload.put("channel_code", "lightnovel")

        val endpoint = "https://" + origin.host + "/api/pc-proxy/api/bff/apk-search-result-v1"
        val reply = requestSource(
            endpoint,
            rawBaseUrl,
            requestHosts,
            emptyList(),
            MAX_TEXT_BYTES,
            image = false,
            method = "POST",
            requestBody = payload.toString().toByteArray(Charsets.UTF_8),
            contentType = "application/json; charset=UTF-8",
        )
        val root = runCatching { JSONObject(decode(reply.bytes, reply.contentType)) }
            .getOrElse { throw WebFailure("SOURCE_API_ERROR", "轻之国度搜索接口没有返回有效 JSON") }
        if (root.optInt("code", -1) != 0) {
            throw WebFailure("SOURCE_API_ERROR", "轻之国度搜索接口暂时不可用")
        }
        val data = root.optJSONObject("data")
            ?: throw WebFailure("SOURCE_API_ERROR", "轻之国度搜索结果缺少 data")
        val list = data.optJSONArray("list") ?: org.json.JSONArray()
        val rows = org.json.JSONArray()
        for (index in 0 until list.length()) {
            val source = list.optJSONObject(index) ?: continue
            val bookId = source.optLong("book_id", 0L)
            if (bookId <= 0L) continue
            val item = JSONObject(source.toString())
            if (!item.has("author") && item.has("author_name")) {
                item.put("author", item.optString("author_name"))
            }
            if (!item.has("cover") && item.has("cover_url")) {
                item.put("cover", item.optString("cover_url"))
            }
            if (!item.has("group_name")) {
                val tags = item.optJSONArray("visible_tags")
                if (tags != null && tags.length() > 0) item.put("group_name", tags.optString(0))
            }
            rows.put(item)
        }
        val normalized = JSONObject()
            .put("collections", rows)
            .put("articles", org.json.JSONArray())
        data.optJSONObject("pagination")?.let { normalized.put("pagination", it) }
        data.optJSONObject("page_info")?.let { normalized.put("page_info", it) }
        return JSONObject().put("code", 0).put("data", normalized).toString()
    }

'''
write(plugin_path, plugin[:start] + new_lightnovel + plugin[end:])

# 5) Light Novel Kingdom login UI stores its security key in localStorage on
# current builds, so do not reject a genuine browser login merely because the
# old token cookie is absent. Reading itself remains anonymous-capable.
activity_path = "android/app/src/main/kotlin/org/mewx/wenku8_flutter/CustomSourceLoginActivity.kt"
activity = read(activity_path)
old_complete = '''    private fun completeLogin() {
        CookieManager.getInstance().flush()
        if (!hasSourceCookie(browser.url)) {
            Toast.makeText(this, "尚未检测到此网站的登录凭据；请先完成登录", Toast.LENGTH_SHORT).show()
            return
        }
        setResult(RESULT_OK)
        finish()
    }
'''
new_complete = '''    private fun completeLogin() {
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
                    var re = /[a-f0-9]{16,}:\\d+:\\d+/i;
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
                val found = !value.isNullOrBlank() && value != "null" && value != "\\\"\\\""
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
'''
if old_complete not in activity:
    raise RuntimeError("CustomSourceLoginActivity: completeLogin block not found")
activity = activity.replace(old_complete, new_complete, 1)
activity = activity.replace(
    '                    status.text = if (hasSourceCookie(url)) {\n                        "已检测到此网站的登录凭据。确认登录成功后，点击右上角“完成登录”。"\n                    } else {\n                        "请在下方网站页面登录；账号与主站分开保存。"\n                    }',
    '                    val isLightNovel = base.host.equals("www.lightnovel.fun", ignoreCase = true) ||\n                        base.host.equals("lightnovel.fun", ignoreCase = true)\n                    status.text = if (isLightNovel) {\n                        "轻之国度公开书籍无需登录即可用于主页和搜索；网站账号登录仅用于账号相关功能。"\n                    } else if (hasSourceCookie(url)) {\n                        "已检测到此网站的登录凭据。确认登录成功后，点击右上角“完成登录”。"\n                    } else {\n                        "请在下方网站页面登录；账号与主站分开保存。"\n                    }',
    1,
)
write(activity_path, activity)

# 6) User-facing copy and build number.
replace_once(
    "lib/book_source_settings_page.dart",
    '轻之国度使用专用 API，需要有效的轻之国度 token；部分网络线路可能无法直连 lightnovel.fun，遇到 DNS 或 HTTPS 连接失败时请检查该域名的网络路由。',
    '轻之国度使用当前公开读取接口，主页、搜索和公开章节不要求账号登录；登录仅用于网站账号相关功能。部分网络线路可能无法直连 lightnovel.fun，遇到 DNS 或 HTTPS 连接失败时请检查该域名的网络路由。',
)
replace_once("pubspec.yaml", "version: 0.5.5+2283", "version: 0.5.5+2284")

print("v2284 compatibility patch applied")
