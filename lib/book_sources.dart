import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'legacy_transport.dart';

typedef BookSourceTextRequest = Future<String> Function(
  String url, {
  required String baseUrl,
});

typedef BookSourceJsonRequest = Future<String> Function(
  String url, {
  required String baseUrl,
  required String body,
});

typedef BookSourceLightNovelSearchRequest = Future<String> Function(
  String query, {
  required String baseUrl,
  required int page,
});

class BookSourceConfig {
  const BookSourceConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.searchUrlTemplate,
    required this.searchItemSelector,
    required this.searchTitleSelector,
    required this.chapterItemSelector,
    required this.chapterContentSelector,
    this.engine = 'css',
    this.enabled = true,
    this.loginUrl = '',
    this.loginHosts = const [],
    this.searchLinkSelector = '',
    this.searchNextPageSelector = '',
    this.searchAuthorSelector = '',
    this.searchGenreSelector = '',
    this.searchSummarySelector = '',
    this.searchCoverSelector = '',
    this.searchCoverAttribute = 'src',
    this.detailTitleSelector = '',
    this.detailAuthorSelector = '',
    this.detailSummarySelector = '',
    this.detailGenreSelector = '',
    this.detailStatusSelector = '',
    this.detailCoverSelector = '',
    this.detailCoverAttribute = 'src',
    this.chapterListUrlTemplate = '',
    this.chapterTitleSelector = '',
    this.chapterHrefSelector = 'a[href]',
    this.chapterNextPageSelector = '',
    this.imageHosts = const [],
  });

  final String id;
  final String name;
  final String engine;
  final String baseUrl;
  final bool enabled;
  final String loginUrl;
  final List<String> loginHosts;
  final String searchUrlTemplate;
  final String searchItemSelector;
  final String searchTitleSelector;
  final String searchLinkSelector;
  final String searchNextPageSelector;
  final String searchAuthorSelector;
  final String searchGenreSelector;
  final String searchSummarySelector;
  final String searchCoverSelector;
  final String searchCoverAttribute;
  final String detailTitleSelector;
  final String detailAuthorSelector;
  final String detailSummarySelector;
  final String detailGenreSelector;
  final String detailStatusSelector;
  final String detailCoverSelector;
  final String detailCoverAttribute;
  final String chapterListUrlTemplate;
  final String chapterItemSelector;
  final String chapterTitleSelector;
  final String chapterHrefSelector;
  final String chapterNextPageSelector;
  final String chapterContentSelector;
  final List<String> imageHosts;

  bool get supportsReading => engine != 'web_login_only';

  Uri get baseUri {
    final uri = Uri.parse(baseUrl.trim());
    return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
  }

  BookSourceConfig withEnabled(bool value) => BookSourceConfig(
    id: id,
    name: name,
    baseUrl: baseUrl,
    enabled: value,
    engine: engine,
    loginUrl: loginUrl,
    loginHosts: loginHosts,
    searchUrlTemplate: searchUrlTemplate,
    searchItemSelector: searchItemSelector,
    searchTitleSelector: searchTitleSelector,
    searchLinkSelector: searchLinkSelector,
    searchNextPageSelector: searchNextPageSelector,
    searchAuthorSelector: searchAuthorSelector,
    searchGenreSelector: searchGenreSelector,
    searchSummarySelector: searchSummarySelector,
    searchCoverSelector: searchCoverSelector,
    searchCoverAttribute: searchCoverAttribute,
    detailTitleSelector: detailTitleSelector,
    detailAuthorSelector: detailAuthorSelector,
    detailSummarySelector: detailSummarySelector,
    detailGenreSelector: detailGenreSelector,
    detailStatusSelector: detailStatusSelector,
    detailCoverSelector: detailCoverSelector,
    detailCoverAttribute: detailCoverAttribute,
    chapterListUrlTemplate: chapterListUrlTemplate,
    chapterItemSelector: chapterItemSelector,
    chapterTitleSelector: chapterTitleSelector,
    chapterHrefSelector: chapterHrefSelector,
    chapterNextPageSelector: chapterNextPageSelector,
    chapterContentSelector: chapterContentSelector,
    imageHosts: imageHosts,
  );

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('书源标识无效');
    }
    if (name.trim().isEmpty || name.trim().length > 40) {
      throw const FormatException('请填写 1–40 个字符的网站名称');
    }
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        baseUrl.length > 2048) {
      throw const FormatException('网站地址必须是完整的 HTTPS 地址');
    }
    if (loginUrl.trim().isNotEmpty) {
      final login = uri.resolve(loginUrl.trim());
      if (login.scheme != 'https' ||
          login.host != uri.host ||
          login.port != uri.port ||
          login.userInfo.isNotEmpty ||
          login.hasFragment) {
        throw const FormatException('登录网址必须与书源使用同一个 HTTPS 域名');
      }
    }
    if (loginHosts.length > 12) {
      throw const FormatException('登录跳转域名最多允许配置 12 个');
    }
    final validLoginHost = RegExp(
      r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:[.][a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*$',
    );
    for (final host in loginHosts) {
      if (host != host.trim().toLowerCase() ||
          !validLoginHost.hasMatch(host) ||
          host.contains('..')) {
        throw FormatException('登录跳转域名无效：$host；只填写主机名，不要填写协议、端口或通配符');
      }
    }
    if (!const {'css', 'lightnovel_fun', 'web_login_only'}.contains(engine)) {
      throw const FormatException('不支持的书源解析引擎');
    }
    if (engine == 'web_login_only') {
      if (loginUrl.trim().isEmpty) {
        throw const FormatException('网页登录入口必须配置登录网址');
      }
    } else if (engine == 'lightnovel_fun') {
      if (uri.host != 'www.lightnovel.fun' || baseUrl.trim() != 'https://www.lightnovel.fun/') {
        throw const FormatException('轻之国度 API 书源必须使用 https://www.lightnovel.fun/');
      }
    } else {
      if (!searchUrlTemplate.contains('{keyword}') ||
          !searchUrlTemplate.contains('{page}') ||
          searchUrlTemplate.length > 2048) {
        throw const FormatException('搜索地址必须包含 {keyword} 和 {page}');
      }
      if (searchItemSelector.trim().isEmpty ||
          searchTitleSelector.trim().isEmpty ||
          chapterItemSelector.trim().isEmpty ||
          chapterContentSelector.trim().isEmpty) {
        throw const FormatException('搜索结果、标题、目录和正文 CSS 选择器不能为空');
      }
    }
    final selectors = [
      searchItemSelector,
      searchTitleSelector,
      searchLinkSelector,
      searchNextPageSelector,
      searchAuthorSelector,
      searchGenreSelector,
      searchSummarySelector,
      searchCoverSelector,
      detailTitleSelector,
      detailAuthorSelector,
      detailSummarySelector,
      detailGenreSelector,
      detailStatusSelector,
      detailCoverSelector,
      chapterItemSelector,
      chapterTitleSelector,
      chapterHrefSelector,
      chapterNextPageSelector,
      chapterContentSelector,
    ].where((value) => value.trim().isNotEmpty);
    final document = parse('<html><body><div></div></body></html>');
    for (final selector in selectors) {
      if (selector.length > 256) {
        throw const FormatException('CSS 选择器不能超过 256 个字符');
      }
      try {
        document.querySelector(selector);
      } catch (_) {
        throw FormatException('CSS 选择器无效：$selector');
      }
    }
    if (chapterListUrlTemplate.length > 2048) {
      throw const FormatException('目录地址模板过长');
    }
    for (final host in imageHosts) {
      if (host.length > 253 ||
          !RegExp(r'^(?=.{1,253}$)[a-zA-Z0-9.-]+$').hasMatch(host) ||
          host.startsWith('.') ||
          host.endsWith('.')) {
        throw FormatException('图片 CDN 域名无效：$host');
      }
    }
    if (imageHosts.length > 12) {
      throw const FormatException('最多允许配置 12 个图片 CDN 域名');
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'engine': engine,
    'baseUrl': baseUrl.trim(),
    'enabled': enabled,
    'loginUrl': loginUrl,
    'loginHosts': loginHosts,
    'searchUrlTemplate': searchUrlTemplate,
    'searchItemSelector': searchItemSelector,
    'searchTitleSelector': searchTitleSelector,
    'searchLinkSelector': searchLinkSelector,
    'searchNextPageSelector': searchNextPageSelector,
    'searchAuthorSelector': searchAuthorSelector,
    'searchGenreSelector': searchGenreSelector,
    'searchSummarySelector': searchSummarySelector,
    'searchCoverSelector': searchCoverSelector,
    'searchCoverAttribute': searchCoverAttribute,
    'detailTitleSelector': detailTitleSelector,
    'detailAuthorSelector': detailAuthorSelector,
    'detailSummarySelector': detailSummarySelector,
    'detailGenreSelector': detailGenreSelector,
    'detailStatusSelector': detailStatusSelector,
    'detailCoverSelector': detailCoverSelector,
    'detailCoverAttribute': detailCoverAttribute,
    'chapterListUrlTemplate': chapterListUrlTemplate,
    'chapterItemSelector': chapterItemSelector,
    'chapterTitleSelector': chapterTitleSelector,
    'chapterHrefSelector': chapterHrefSelector,
    'chapterNextPageSelector': chapterNextPageSelector,
    'chapterContentSelector': chapterContentSelector,
    'imageHosts': imageHosts,
  };

  factory BookSourceConfig.fromJson(Map<String, dynamic> value) {
    String string(String key, [String fallback = '']) =>
        value[key] is String ? value[key] as String : fallback;
    return BookSourceConfig(
      id: string('id'),
      name: string('name'),
      engine: string('engine', 'css'),
      baseUrl: string('baseUrl'),
      enabled: value['enabled'] != false,
      loginUrl: string('loginUrl'),
      loginHosts: value['loginHosts'] is List
          ? (value['loginHosts'] as List)
                .whereType<String>()
                .map((host) => host.trim().toLowerCase())
                .where((host) => host.isNotEmpty)
                .toList(growable: false)
          : const [],
      searchUrlTemplate: string('searchUrlTemplate'),
      searchItemSelector: string('searchItemSelector'),
      searchTitleSelector: string('searchTitleSelector'),
      searchLinkSelector: string('searchLinkSelector'),
      searchNextPageSelector: string('searchNextPageSelector'),
      searchAuthorSelector: string('searchAuthorSelector'),
      searchGenreSelector: string('searchGenreSelector'),
      searchSummarySelector: string('searchSummarySelector'),
      searchCoverSelector: string('searchCoverSelector'),
      searchCoverAttribute: string('searchCoverAttribute', 'src'),
      detailTitleSelector: string('detailTitleSelector'),
      detailAuthorSelector: string('detailAuthorSelector'),
      detailSummarySelector: string('detailSummarySelector'),
      detailGenreSelector: string('detailGenreSelector'),
      detailStatusSelector: string('detailStatusSelector'),
      detailCoverSelector: string('detailCoverSelector'),
      detailCoverAttribute: string('detailCoverAttribute', 'src'),
      chapterListUrlTemplate: string('chapterListUrlTemplate'),
      chapterItemSelector: string('chapterItemSelector'),
      chapterTitleSelector: string('chapterTitleSelector'),
      chapterHrefSelector: string('chapterHrefSelector', 'a[href]'),
      chapterNextPageSelector: string('chapterNextPageSelector'),
      chapterContentSelector: string('chapterContentSelector'),
      imageHosts: value['imageHosts'] is List
          ? (value['imageHosts'] as List)
                .whereType<String>()
                .map((host) => host.trim().toLowerCase())
                .where((host) => host.isNotEmpty)
                .take(12)
                .toList(growable: false)
          : const [],
    );
  }
}

class BookSourceStore extends ChangeNotifier {
  BookSourceStore(this.preferences);
  static const preferenceKey = 'custom_book_sources_v1';
  static const homepageSourcePreferenceKey = 'homepage_book_source_v1';
  static const loginSourcePreferenceKey = 'login_book_source_v1';
  static const loggedInSourcesPreferenceKey = 'logged_in_book_sources_v1';
  static const loginHomepageSeparationMigrationKey = 'login_homepage_separation_v1';
  static BookSourceStore? instance;

  final SharedPreferences preferences;
  final List<BookSourceConfig> _sources = [];
  List<BookSourceConfig> get sources => List.unmodifiable(_sources);
  List<BookSourceConfig> get enabledSources => List.unmodifiable(
    _sources.where((source) => source.enabled && source.supportsReading),
  );
  List<BookSourceConfig> get loginSources => List.unmodifiable(
    _sources.where((source) => source.loginUrl.trim().isNotEmpty),
  );

  /// Built-in site shortcuts. Only the Light Novel Kingdom preset currently
  /// has a native reader adapter; the others are isolated WebView login entries.
  static const List<BookSourceConfig> builtInPresets = [
    BookSourceConfig(
      id: 'lightnovel-fun',
      name: '轻之国度',
      baseUrl: 'https://www.lightnovel.fun/',
      engine: 'lightnovel_fun',
      loginUrl: '/',
      loginHosts: ['lightnovel.fun'],
      searchUrlTemplate: '',
      searchItemSelector: '',
      searchTitleSelector: '',
      chapterItemSelector: '',
      chapterContentSelector: '',
      imageHosts: ['lightnovel.fun'],
    ),
    BookSourceConfig(
      id: 'linovelib-web',
      name: '哔哩轻小说',
      baseUrl: 'https://www.linovelib.com/',
      engine: 'web_login_only',
      enabled: false,
      loginUrl: '/login.php',
      searchUrlTemplate: '',
      searchItemSelector: '',
      searchTitleSelector: '',
      chapterItemSelector: '',
      chapterContentSelector: '',
    ),
    BookSourceConfig(
      id: 'esjzone-web',
      name: 'ESJ Zone',
      baseUrl: 'https://www.esjzone.one/',
      engine: 'web_login_only',
      enabled: false,
      loginUrl: '/my/profile.html',
      searchUrlTemplate: '',
      searchItemSelector: '',
      searchTitleSelector: '',
      chapterItemSelector: '',
      chapterContentSelector: '',
    ),
    BookSourceConfig(
      id: 'linovel-net-web',
      name: '轻之文库',
      baseUrl: 'https://www.linovel.net/',
      engine: 'web_login_only',
      enabled: false,
      loginUrl: '/auth/login',
      searchUrlTemplate: '',
      searchItemSelector: '',
      searchTitleSelector: '',
      chapterItemSelector: '',
      chapterContentSelector: '',
    ),
  ];

  List<BookSourceConfig> get loginOptions {
    final options = <String, BookSourceConfig>{
      for (final source in loginSources) source.id: source,
    };
    for (final preset in builtInPresets) {
      options.putIfAbsent(preset.id, () => preset);
    }
    return List.unmodifiable(options.values);
  }

  Future<BookSourceConfig> installPreset(String id) async {
    final existing = byId(id);
    if (existing != null) return existing;
    BookSourceConfig? preset;
    for (final candidate in builtInPresets) {
      if (candidate.id == id) {
        preset = candidate;
        break;
      }
    }
    if (preset == null) {
      throw const FormatException('找不到这个内置网站预设');
    }
    await save(preset);
    return byId(id)!;
  }

  /// null means the original Wenku8 website; custom IDs select a configured source.
  String? get homepageSourceId {
    final id = preferences.getString(homepageSourcePreferenceKey);
    final source = id == null ? null : byId(id);
    return source != null && source.supportsReading ? id : null;
  }
  BookSourceConfig? get homepageSource {
    final id = homepageSourceId;
    return id == null ? null : byId(id);
  }

  /// The account page defaults to Wenku8 and can independently select another
  /// configured website for its next login.
  String? get loginSourceId {
    final id = preferences.getString(loginSourcePreferenceKey);
    final source = id == null ? null : byId(id);
    return source != null && source.loginUrl.trim().isNotEmpty ? id : null;
  }
  BookSourceConfig? get loginSource {
    final id = loginSourceId;
    return id == null ? null : byId(id);
  }

  bool isSourceLoggedIn(String id) =>
      (preferences.getStringList(loggedInSourcesPreferenceKey) ?? const [])
          .contains(id);

  Future<void> setHomepageSourceId(String? id) async {
    if (id != null) {
      final source = byId(id);
      if (source == null || !source.supportsReading) {
        throw const FormatException('该网站目前仅支持网页登录，尚不能设为阅读书源');
      }
    }
    if (id == null) {
      await preferences.remove(homepageSourcePreferenceKey);
    } else {
      await preferences.setString(homepageSourcePreferenceKey, id);
    }
    notifyListeners();
  }

  Future<void> setLoginSourceId(String? id) async {
    if (id != null) {
      final source = byId(id);
      if (source == null || source.loginUrl.trim().isEmpty) {
        throw const FormatException('该书源没有配置独立登录网址');
      }
      await preferences.setString(loginSourcePreferenceKey, id);
    } else {
      await preferences.remove(loginSourcePreferenceKey);
    }
    notifyListeners();
  }

  Future<void> completeSourceLogin(String id) async {
    final source = byId(id);
    if (source == null || source.loginUrl.trim().isEmpty) {
      throw const FormatException('登录书源已不存在，请重新选择');
    }
    final loggedIn = <String>{
      ...(preferences.getStringList(loggedInSourcesPreferenceKey) ?? const <String>[]),
      id,
    }.toList()..sort();
    await preferences.setStringList(loggedInSourcesPreferenceKey, loggedIn);
    await preferences.setString(loginSourcePreferenceKey, id);
    // Login identity and homepage catalog are independent settings.
    notifyListeners();
  }

  Future<void> completeOfficialLogin() async {
    await preferences.remove(loginSourcePreferenceKey);
    notifyListeners();
  }

  void _refreshImageOrigins() {
    LegacyTransport.configureSourceImageOrigins([
      for (final source in _sources)
        (baseUrl: source.baseUrl, imageHosts: source.imageHosts),
    ]);
  }

  BookSourceConfig? byId(String id) {
    for (final source in _sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  Future<void> _migrateLoginHomepageSeparation() async {
    if (preferences.getBool(loginHomepageSeparationMigrationKey) == true) {
      return;
    }
    // Older builds automatically changed the homepage to Light Novel Kingdom
    // when its login preset was selected. Restore Wenku8 as the safe default
    // once; users can still choose Light Novel Kingdom explicitly in settings.
    if (preferences.getString(homepageSourcePreferenceKey) == 'lightnovel-fun') {
      await preferences.remove(homepageSourcePreferenceKey);
    }
    // Older builds marked a source as logged in after detecting any cookie.
    // Reconfirm Light Novel Kingdom with its required token cookie instead.
    final loggedIn = preferences.getStringList(loggedInSourcesPreferenceKey);
    if (loggedIn != null && loggedIn.contains('lightnovel-fun')) {
      await preferences.setStringList(
        loggedInSourcesPreferenceKey,
        loggedIn.where((id) => id != 'lightnovel-fun').toList(),
      );
    }
    await preferences.setBool(loginHomepageSeparationMigrationKey, true);
  }

  Future<void> load() async {
    await _migrateLoginHomepageSeparation();
    _sources.clear();
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) {
      _refreshImageOrigins();
      notifyListeners();
      return;
    }
    var migratedLoginHosts = false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.length > 20) {
        throw const FormatException();
      }
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final config = Map<String, dynamic>.from(item);
        if (config['id'] == 'lightnovel-fun') {
          final savedHosts = config['loginHosts'] is List
              ? (config['loginHosts'] as List).whereType<String>().toList()
              : <String>[];
          if (!savedHosts.map((host) => host.toLowerCase()).contains('lightnovel.fun')) {
            config['loginHosts'] = [...savedHosts, 'lightnovel.fun'];
            migratedLoginHosts = true;
          }
        }
        final source = BookSourceConfig.fromJson(config);
        source.validate();
        if (_sources.any((entry) => entry.id == source.id)) continue;
        _sources.add(source);
      }
    } catch (_) {
      _sources.clear();
      throw const FormatException('书源配置损坏，请重新导入配置');
    }
    if (migratedLoginHosts) {
      await preferences.setString(
        preferenceKey,
        jsonEncode(_sources.map((source) => source.toJson()).toList()),
      );
    }
    _refreshImageOrigins();
    notifyListeners();
  }

  Future<void> save(BookSourceConfig source) async {
    source.validate();
    final index = _sources.indexWhere((item) => item.id == source.id);
    if (index < 0 && _sources.length >= 20) {
      throw const FormatException('最多添加 20 个自定义书源');
    }
    final next = [..._sources];
    if (index < 0) {
      next.add(source);
    } else {
      next[index] = source;
    }
    await preferences.setString(
      preferenceKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    _sources
      ..clear()
      ..addAll(next);
    _refreshImageOrigins();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final next = _sources.where((item) => item.id != id).toList();
    await preferences.setString(
      preferenceKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    _sources
      ..clear()
      ..addAll(next);
    if (preferences.getString(homepageSourcePreferenceKey) == id) {
      await preferences.remove(homepageSourcePreferenceKey);
    }
    if (preferences.getString(loginSourcePreferenceKey) == id) {
      await preferences.remove(loginSourcePreferenceKey);
    }
    final loggedIn = preferences
        .getStringList(loggedInSourcesPreferenceKey)
        ?.where((sourceId) => sourceId != id)
        .toList();
    if (loggedIn != null) {
      await preferences.setStringList(loggedInSourcesPreferenceKey, loggedIn);
    }
    _refreshImageOrigins();
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final source = byId(id);
    if (source == null) return;
    await save(source.withEnabled(enabled));
  }
}

class BookSourceRepository {
  BookSourceRepository(
    this.source, {
    BookSourceTextRequest? request,
    BookSourceJsonRequest? jsonRequest,
    BookSourceLightNovelSearchRequest? lightNovelSearchRequest,
  }) : _request = request ?? LegacyTransport.getSourceText,
       _jsonRequest = jsonRequest ?? LegacyTransport.postSourceJson,
       _lightNovelSearchRequest = lightNovelSearchRequest ?? LegacyTransport.searchLightNovel;

  final BookSourceConfig source;
  final BookSourceTextRequest _request;
  final BookSourceJsonRequest _jsonRequest;
  final BookSourceLightNovelSearchRequest _lightNovelSearchRequest;

  void _requireReaderSupport() {
    if (!source.supportsReading) {
      throw const FormatException(
        '该网站目前仅提供网页登录入口，App 内搜索和阅读尚未适配',
      );
    }
  }

  Future<String> _fetch(String url) async {
    final uri = _resolvePage(url);
    if (uri == null) throw const FormatException('书源链接超出了配置的网站域名');
    return _request(uri.toString(), baseUrl: source.baseUrl);
  }

  Future<NovelPage> search(
    String keyword, {
    int page = 1,
    String field = 'title',
  }) async {
    _requireReaderSupport();
    if (page < 1 || page > 10000) {
      throw ArgumentError.value(page, 'page');
    }
    if (source.engine == 'lightnovel_fun') {
      return _searchLightNovel(keyword, page: page);
    }
    final url = source.searchUrlTemplate
        .replaceAll('{keyword}', Uri.encodeQueryComponent(keyword))
        .replaceAll('{page}', page.toString())
        .replaceAll('{field}', field == 'author' ? 'author' : 'title');
    final html = await _fetch(source.baseUri.resolve(url).toString());
    final document = parse(html);
    final rows = document.querySelectorAll(source.searchItemSelector);
    final books = <Novel>[];
    final seen = <int>{};
    for (final row in rows.take(100)) {
      final titleNode = _query(row, source.searchTitleSelector) ?? row;
      final title = _clean(titleNode.text);
      if (title.isEmpty) continue;
      final linkNode = _linkNode(row, titleNode, source.searchLinkSelector);
      final href = linkNode?.attributes['href'] ?? '';
      final bookUrl = _resolvePage(href);
      if (bookUrl == null) continue;
      final id = _stableId('${source.id}|$bookUrl', 0x40000000);
      if (!seen.add(id)) continue;
      final author = _text(row, source.searchAuthorSelector);
      final summary = _text(row, source.searchSummarySelector);
      final genre = _text(row, source.searchGenreSelector);
      final cover = _attribute(
        row,
        source.searchCoverSelector,
        source.searchCoverAttribute,
      );
      final coverUrl = _resolveImage(cover);
      books.add(
        Novel(
          id: id,
          title: title,
          author: author,
          genre: genre,
          summary: summary,
          colors: _colors(id),
          coverUrl: coverUrl?.toString(),
          sourceId: source.id,
          sourceName: source.name,
          sourceUrl: bookUrl.toString(),
          sourceBaseUrl: source.baseUrl,
          sourceImageHosts: source.imageHosts,
        ),
      );
    }
    final nextSelector = source.searchNextPageSelector.trim();
    final nextLink = nextSelector.isEmpty ? null : _query(document, nextSelector);
    final nextUrl = _resolvePage(nextLink?.attributes['href'] ?? '');
    return NovelPage(
      items: List.unmodifiable(books),
      page: page,
      totalPages: nextSelector.isEmpty ? null : nextUrl == null ? page : null,
      totalItems: null,
    );
  }

  Future<Novel> detail(Novel seed) async {
    _requireReaderSupport();
    if (source.engine == 'lightnovel_fun') return _lightNovelDetail(seed);
    final bookUrl = seed.sourceUrl;
    if (bookUrl == null || bookUrl.isEmpty) {
      throw const FormatException('这本书缺少原始网站地址');
    }
    final html = await _fetch(bookUrl);
    final document = parse(html);
    final title = _text(document, source.detailTitleSelector);
    final author = _text(document, source.detailAuthorSelector);
    final summary = _text(document, source.detailSummarySelector);
    final genre = _text(document, source.detailGenreSelector);
    final status = _text(document, source.detailStatusSelector);
    final cover = _attribute(
      document,
      source.detailCoverSelector,
      source.detailCoverAttribute,
    );
    return Novel(
      id: seed.id,
      title: title.isEmpty ? seed.title : title,
      author: author.isEmpty ? seed.author : author,
      genre: genre,
      summary: summary.isEmpty ? seed.summary : summary,
      colors: seed.colors,
      isComplete: status.contains('完结') || status.contains('完本'),
      coverUrl: _resolveImage(cover)?.toString() ?? seed.coverUrl,
      chapterCount: seed.chapterCount,
      sourceId: source.id,
      sourceName: source.name,
      sourceUrl: seed.sourceUrl,
      sourceBaseUrl: source.baseUrl,
      sourceImageHosts: source.imageHosts,
    );
  }

  Future<List<NovelChapter>> chapters(Novel novel) async {
    _requireReaderSupport();
    if (source.engine == 'lightnovel_fun') return _lightNovelChapters(novel);
    final bookUrl = novel.sourceUrl;
    if (bookUrl == null || bookUrl.isEmpty) {
      throw const FormatException('这本书缺少原始网站地址');
    }
    final rawUrl = source.chapterListUrlTemplate.trim().isEmpty
        ? bookUrl
        : source.chapterListUrlTemplate.replaceAll('{bookUrl}', bookUrl);
    var currentUrl = _resolvePage(source.baseUri.resolve(rawUrl).toString());
    if (currentUrl == null) {
      throw const FormatException('目录地址超出了配置的网站域名');
    }
    final result = <NovelChapter>[];
    final seenIds = <int>{};
    final visited = <String>{};
    for (var page = 0; page < 20 && result.length < 5000; page++) {
      if (!visited.add(currentUrl.toString())) break;
      final html = await _fetch(currentUrl.toString());
      final document = parse(html);
      final rows = document.querySelectorAll(source.chapterItemSelector);
      for (final row in rows) {
        if (result.length >= 5000) break;
        final titleNode = source.chapterTitleSelector.trim().isEmpty
            ? row
            : _query(row, source.chapterTitleSelector) ?? row;
        final linkNode = _linkNode(row, titleNode, source.chapterHrefSelector);
        final href = linkNode?.attributes['href'] ?? '';
        final chapterUrl = _resolvePage(href);
        final title = _clean(titleNode.text);
        if (title.isEmpty || chapterUrl == null) continue;
        final id = _stableId(
          '${source.id}|${novel.id}|${chapterUrl}',
          0x20000000,
        );
        if (!seenIds.add(id)) continue;
        result.add(
          NovelChapter(
            title,
            '',
            id: id,
            sourceId: source.id,
            sourceUrl: chapterUrl.toString(),
          ),
        );
      }
      if (source.chapterNextPageSelector.trim().isEmpty) break;
      final next = _query(document, source.chapterNextPageSelector);
      final href = next?.attributes['href'] ?? '';
      final nextUrl = _resolvePage(href);
      if (nextUrl == null || visited.contains(nextUrl.toString())) break;
      currentUrl = nextUrl;
    }
    if (result.isEmpty) {
      throw const FormatException('没有解析到目录，请检查目录 CSS 选择器和链接选择器');
    }
    return List.unmodifiable(result);
  }


  Future<Map<String, dynamic>> _lightNovelApi(
    String path,
    Map<String, Object?> body,
  ) async {
    final url = _resolvePage(
      source.baseUri.resolve('/api/pc-proxy/api/$path').toString(),
    );
    if (url == null) {
      throw const FormatException('轻之国度 API 地址不在书源域名内');
    }
    final raw = await _jsonRequest(
      url.toString(),
      baseUrl: source.baseUrl,
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('轻之国度 API 返回格式无效');
    }
    final code = decoded['code'];
    if (code != null && code.toString() != '0') {
      final message = decoded['message'] ?? decoded['msg'] ?? decoded['error'];
      throw FormatException(
        '轻之国度接口返回错误 ' + code.toString() +
        (message == null ? '' : '：' + _clean(message.toString())),
      );
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is List) return {'list': data};
    throw const FormatException('轻之国度 API 没有返回数据');
  }

  Future<List<Map<String, dynamic>>> _lightNovelPaged(
    String path,
    Map<String, Object?> parameters,
    String idKey,
  ) async {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var page = 1; page <= 20; page++) {
      final data = await _lightNovelApi(path, {
        ...parameters,
        'page': page,
        'pageSize': 50,
      });
      final rawItems = data['list'];
      final items = rawItems is List
          ? rawItems.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      for (final item in items) {
        final id = item[idKey]?.toString().trim() ?? '';
        if (id.isNotEmpty && seen.add(id)) result.add(item);
      }
      final pagination = data['pagination'] is Map
          ? Map<String, dynamic>.from(data['pagination'] as Map)
          : data['page_info'] is Map
              ? Map<String, dynamic>.from(data['page_info'] as Map)
              : <String, dynamic>{};
      final pageCount = int.tryParse(
            (pagination['page_count'] ?? pagination['pageCount'] ?? '').toString(),
          ) ??
          0;
      final total = int.tryParse((pagination['total'] ?? '').toString()) ?? 0;
      if (items.isEmpty ||
          items.length < 50 ||
          (pageCount > 0 && page >= pageCount) ||
          (total > 0 && result.length >= total)) {
        break;
      }
    }
    return result;
  }

  int? _lightNovelBookId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host != source.baseUri.host) return null;
    final match = RegExp(r'/(?:book|reader)/(\d+)').firstMatch(uri.path);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<NovelPage> _searchLightNovel(String keyword, {required int page}) async {
    final raw = await _lightNovelSearchRequest(
      keyword,
      baseUrl: source.baseUrl,
      page: page,
    );
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('轻之国度搜索接口返回格式无效');
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('轻之国度搜索结果中没有 data 字段');
    }
    final rows = <Map<String, dynamic>>[];
    for (final key in const ['collections', 'articles']) {
      final values = data[key];
      if (values is List) {
        rows.addAll(values.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
      }
    }
    final books = <Novel>[];
    final seen = <int>{};
    for (final row in rows.take(100)) {
      final directId = int.tryParse((row['book_id'] ?? row['bookId'] ?? '').toString());
      final seriesId = int.tryParse((row['sid'] ?? '').toString()) ?? 0;
      final articleId = int.tryParse((row['aid'] ?? '').toString()) ?? 0;
      final bookId = directId ?? (seriesId > 0 ? seriesId : articleId);
      final title = _clean(
        (row['title'] ?? row['name'] ?? row['series_name'] ?? '').toString(),
      );
      if (bookId <= 0 || title.isEmpty) continue;
      final id = _stableId(source.id + '|' + bookId.toString(), 0x40000000);
      if (!seen.add(id)) continue;
      final cover = (row['cover'] ?? row['cover_url'] ?? '').toString();
      books.add(
        Novel(
          id: id,
          title: title,
          author: _clean((row['author'] ?? row['author_name'] ?? '').toString()),
          genre: _clean((row['group_name'] ?? row['kind'] ?? '').toString()),
          summary: _clean((row['summary'] ?? row['intro'] ?? '').toString()),
          colors: _colors(id),
          coverUrl: _resolveImage(cover)?.toString(),
          sourceId: source.id,
          sourceName: source.name,
          sourceUrl: source.baseUri.resolve('/book/$bookId').toString(),
          sourceBaseUrl: source.baseUrl,
          sourceImageHosts: source.imageHosts,
        ),
      );
    }
    return NovelPage(items: List.unmodifiable(books), page: page);
  }

  Future<Novel> _lightNovelDetail(Novel seed) async {
    final bookId = _lightNovelBookId(seed.sourceUrl);
    if (bookId == null) throw const FormatException('无法从轻之国度书籍链接识别书号');
    final data = await _lightNovelApi(
      'new-content-read/get-book-detail',
      {'book_id': bookId, 'with_volumes': 0},
    );
    final tagsRaw = (data['visible_tags'] is List && (data['visible_tags'] as List).isNotEmpty)
        ? data['visible_tags'] as List
        : data['tags'] is List ? data['tags'] as List : const [];
    final tags = tagsRaw.map((tag) {
      if (tag is Map) return _clean((tag['name'] ?? tag['text'] ?? '').toString());
      return _clean(tag.toString());
    }).where((tag) => tag.isNotEmpty).toSet().toList();
    final workType = data['work_type'];
    final workTypeText = workType is Map ? (workType['text'] ?? '').toString() : '';
    final status = _clean(
      (data['status'] ?? data['serial_status'] ?? data['update_status'] ?? '').toString(),
    );
    final completed = data['is_complete'] == true ||
        data['is_finished'] == true ||
        status.contains('完结') ||
        status.contains('完本') ||
        status.toLowerCase() == 'finished' ||
        status.toLowerCase() == 'complete';
    final cover = _resolveImage((data['cover_url'] ?? '').toString())?.toString();
    final detailTitle = _clean((data['title'] ?? '').toString());
    final detailAuthor = _clean((data['author_name'] ?? '').toString());
    final detailSummary = _clean((data['summary_short'] ?? '').toString());
    return Novel(
      id: seed.id,
      title: detailTitle.isEmpty ? seed.title : detailTitle,
      author: detailAuthor.isEmpty ? seed.author : detailAuthor,
      genre: tags.isNotEmpty ? tags.join(' · ') : workTypeText,
      summary: detailSummary.isEmpty ? seed.summary : detailSummary,
      colors: seed.colors,
      isComplete: completed,
      coverUrl: cover ?? seed.coverUrl,
      chapterCount: seed.chapterCount,
      sourceId: source.id,
      sourceName: source.name,
      sourceUrl: seed.sourceUrl,
      sourceBaseUrl: source.baseUrl,
      sourceImageHosts: source.imageHosts,
    );
  }

  Future<List<NovelChapter>> _lightNovelChapters(Novel novel) async {
    final bookId = _lightNovelBookId(novel.sourceUrl);
    if (bookId == null) throw const FormatException('无法从轻之国度书籍链接识别书号');
    final volumes = await _lightNovelPaged(
      'new-content-read/get-book-volumes',
      {'book_id': bookId},
      'volume_id',
    );
    if (volumes.isEmpty) {
      throw const FormatException('这本书没有可读取的在线目录，可能仅提供 EPUB 下载');
    }
    final chapters = <NovelChapter>[];
    final seen = <int>{};
    for (final volume in volumes.take(200)) {
      final volumeId = int.tryParse((volume['volume_id'] ?? '').toString());
      if (volumeId == null || volumeId <= 0) continue;
      final volumeTitle = _clean((volume['title'] ?? '').toString());
      final rows = await _lightNovelPaged(
        'new-content-read/get-volume-chapters',
        {'book_id': bookId, 'volume_id': volumeId},
        'chapter_id',
      );
      for (final row in rows) {
        final chapterId = int.tryParse((row['chapter_id'] ?? '').toString());
        if (chapterId == null || chapterId <= 0 || !seen.add(chapterId)) continue;
        final id = _stableId(
          source.id + '|' + bookId.toString() + '|' + chapterId.toString(),
          0x20000000,
        );
        final volumeStableId = _stableId(
          source.id + '|' + bookId.toString() + '|' + volumeId.toString(),
          0x10000000,
        );
        final title = _clean((row['title'] ?? '').toString());
        chapters.add(
          NovelChapter(
            title.isEmpty ? '章节 $chapterId' : title,
            '',
            id: id,
            volumeId: volumeStableId,
            volumeTitle: volumeTitle,
            sourceId: source.id,
            sourceUrl: source.baseUri.resolve('/reader/$bookId/$chapterId').toString(),
          ),
        );
        if (chapters.length >= 5000) break;
      }
      if (chapters.length >= 5000) break;
    }
    if (chapters.isEmpty) throw const FormatException('轻之国度返回了卷信息，但没有解析到章节');
    return List.unmodifiable(chapters);
  }

  Future<String> _lightNovelChapterContent(NovelChapter chapter) async {
    final url = Uri.tryParse(chapter.sourceUrl ?? '');
    final match = url == null
        ? null
        : RegExp(r'/reader/(\d+)/(\d+)').firstMatch(url.path);
    if (url == null || url.host != source.baseUri.host || match == null) {
      throw const FormatException('轻之国度章节链接无效');
    }
    final bookId = int.parse(match.group(1)!);
    final chapterId = int.parse(match.group(2)!);
    final data = await _lightNovelApi(
      'new-content-read/get-chapter-detail',
      {'book_id': bookId, 'chapter_id': chapterId},
    );
    final snapshot = data['body_snapshot'] is Map
        ? Map<String, dynamic>.from(data['body_snapshot'] as Map)
        : <String, dynamic>{};
    final html = (snapshot['body_html'] ?? '').toString();
    final plain = (snapshot['body_text'] ?? '').toString();
    if (html.trim().isNotEmpty) {
      final document = parse('<div id="lightnovel-body">$html</div>');
      final root = document.querySelector('#lightnovel-body');
      if (root != null) {
        final text = root.nodes.map(_flattenSourceNode).join();
        if (text.trim().isNotEmpty) return text.trim();
      }
    }
    if (plain.trim().isNotEmpty) {
      return plain
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }
    final locked = data['locked'] == true || data['locked'].toString() == '1';
    final coin = int.tryParse((data['coin_price'] ?? '0').toString()) ?? 0;
    final brave = int.tryParse((data['brave_required'] ?? '0').toString()) ?? 0;
    if (locked || coin > 0 || brave > 0) {
      return coin > 0
          ? '本章为付费章节，需要在轻之国度网站按站点规则购买后阅读。'
          : brave > 0
              ? '本章需要达到轻之国度要求的勇气值。'
              : '本章尚未解锁，请在轻之国度网站查看访问条件。';
    }
    throw const FormatException('轻之国度没有返回章节正文');
  }

  Future<String> chapterContent(NovelChapter chapter) async {
    _requireReaderSupport();
    if (source.engine == 'lightnovel_fun') return _lightNovelChapterContent(chapter);
    final url = chapter.sourceUrl;
    if (url == null || url.isEmpty) {
      throw const FormatException('章节缺少原始网页地址');
    }
    final html = await _fetch(url);
    final document = parse(html);
    final root = _query(document, source.chapterContentSelector);
    if (root == null) {
      throw const FormatException('没有找到正文区域，请检查正文 CSS 选择器');
    }
    final text = root.nodes.map(_flattenSourceNode).join();
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (normalized.isEmpty) throw const FormatException('章节正文为空');
    return normalized;
  }

  String _flattenSourceNode(Node node) {
    if (node is Text) return node.text;
    if (node is! Element) return '';
    final tag = node.localName;
    if (tag == 'img') {
      final raw = node.attributes['src'] ??
          node.attributes['data-src'] ??
          node.attributes['data-original'] ??
          '';
      final image = _resolveImage(raw);
      return image == null
          ? ''
          : '\n\n<!--image-->${image.toString()}<!--image-->\n\n';
    }
    if (const {
      'script',
      'style',
      'noscript',
      'iframe',
      'form',
      'nav',
      'header',
      'footer',
      'button',
      'svg',
    }.contains(tag)) {
      return '';
    }
    if (tag == 'br') return '\n';
    final content = node.nodes.map(_flattenSourceNode).join();
    if (const {
      'p',
      'div',
      'section',
      'article',
      'li',
      'tr',
      'td',
      'blockquote',
      'h1',
      'h2',
      'h3',
      'h4',
      'hr',
    }.contains(tag)) {
      return '\n\n' + content + '\n\n';
    }
    return content;
  }

  Uri? _resolvePage(String raw) {
    final input = Uri.tryParse(raw.trim());
    if (input == null || raw.trim().isEmpty) return null;
    final resolved = source.baseUri.resolveUri(input);
    final base = source.baseUri;
    if (resolved.scheme != 'https' ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        resolved.userInfo.isNotEmpty ||
        resolved.hasFragment) {
      return null;
    }
    return resolved;
  }

  Uri? _resolveImage(String raw) {
    if (raw.trim().isEmpty) return null;
    final input = Uri.tryParse(raw.trim());
    if (input == null) return null;
    final resolved = source.baseUri.resolveUri(input);
    final base = source.baseUri;
    final hostAllowed = resolved.host == base.host ||
        source.imageHosts.any(
          (host) => resolved.host == host || resolved.host.endsWith('.$host'),
        );
    if (resolved.scheme != 'https' ||
        !hostAllowed ||
        resolved.userInfo.isNotEmpty ||
        resolved.hasFragment ||
        (resolved.hasPort && resolved.port != 443)) {
      return null;
    }
    return resolved;
  }
}

Element? _query(Object root, String selector) {
  if (selector.trim().isEmpty) return null;
  try {
    if (root is Document) return root.querySelector(selector);
    if (root is Element) return root.querySelector(selector);
  } catch (_) {
    return null;
  }
  return null;
}

String _text(Object root, String selector) =>
    _clean(_query(root, selector)?.text ?? '');

String _attribute(Object root, String selector, String attribute) {
  final element = _query(root, selector);
  if (element == null) return '';
  final value = element.attributes[attribute] ??
      element.attributes['data-src'] ??
      element.attributes['data-original'] ??
      '';
  return value.trim();
}

Element? _linkNode(Element row, Element title, String selector) {
  final selected = _query(row, selector);
  if (selected != null) return selected;
  if (title.localName == 'a' && title.attributes.containsKey('href')) {
    return title;
  }
  Node? ancestor = title.parent;
  while (ancestor is Element) {
    if (ancestor.localName == 'a' && ancestor.attributes.containsKey('href')) {
      return ancestor;
    }
    ancestor = ancestor.parent;
  }
  return row.querySelector('a[href]');
}

String _clean(String raw) => raw
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('\u00a0', ' ')
    .trim();

int _stableId(String value, int prefix) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return prefix | (hash & 0x1fffffff);
}

List<Color> _colors(int id) {
  const palettes = [
    [Color(0xFF6D89A9), Color(0xFF263A58)],
    [Color(0xFFB37C80), Color(0xFF593D57)],
    [Color(0xFF6D9C94), Color(0xFF244F57)],
    [Color(0xFFB38D62), Color(0xFF574333)],
    [Color(0xFF887EB0), Color(0xFF39345F)],
  ];
  return palettes[id % palettes.length];
}
