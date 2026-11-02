import 'dart:convert';
import 'dart:typed_data';

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
    this.enabled = true,
    this.searchLinkSelector = '',
    this.searchAuthorSelector = '',
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
    this.imageHosts = const [],
  });

  final String id;
  final String name;
  final String baseUrl;
  final bool enabled;
  final String searchUrlTemplate;
  final String searchItemSelector;
  final String searchTitleSelector;
  final String searchLinkSelector;
  final String searchAuthorSelector;
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
  final String chapterContentSelector;
  final List<String> imageHosts;

  Uri get baseUri {
    final uri = Uri.parse(baseUrl.trim());
    return uri.replace(path: uri.path.endsWith('/') ? uri.path : uri.path + '/');
  }

  BookSourceConfig withEnabled(bool value) => BookSourceConfig(
    id: id,
    name: name,
    baseUrl: baseUrl,
    enabled: value,
    searchUrlTemplate: searchUrlTemplate,
    searchItemSelector: searchItemSelector,
    searchTitleSelector: searchTitleSelector,
    searchLinkSelector: searchLinkSelector,
    searchAuthorSelector: searchAuthorSelector,
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
    chapterContentSelector: chapterContentSelector,
    imageHosts: imageHosts,
  );

  void validate() {
    if (id.trim().isEmpty || id.length > 80) {
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
    final selectors = [
      searchItemSelector,
      searchTitleSelector,
      searchLinkSelector,
      searchAuthorSelector,
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
    'baseUrl': baseUrl.trim(),
    'enabled': enabled,
    'searchUrlTemplate': searchUrlTemplate,
    'searchItemSelector': searchItemSelector,
    'searchTitleSelector': searchTitleSelector,
    'searchLinkSelector': searchLinkSelector,
    'searchAuthorSelector': searchAuthorSelector,
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
    'chapterContentSelector': chapterContentSelector,
    'imageHosts': imageHosts,
  };

  factory BookSourceConfig.fromJson(Map<String, dynamic> value) {
    String string(String key, [String fallback = '']) =>
        value[key] is String ? value[key] as String : fallback;
    return BookSourceConfig(
      id: string('id'),
      name: string('name'),
      baseUrl: string('baseUrl'),
      enabled: value['enabled'] != false,
      searchUrlTemplate: string('searchUrlTemplate'),
      searchItemSelector: string('searchItemSelector'),
      searchTitleSelector: string('searchTitleSelector'),
      searchLinkSelector: string('searchLinkSelector'),
      searchAuthorSelector: string('searchAuthorSelector'),
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
      chapterContentSelector: string('chapterContentSelector'),
      imageHosts: value['imageHosts'] is List
          ? (value['imageHosts'] as List)
                .whereType<String>()
                .take(12)
                .toList(growable: false)
          : const [],
    );
  }
}

class BookSourceStore extends ChangeNotifier {
  BookSourceStore(this.preferences);
  static const preferenceKey = 'custom_book_sources_v1';
  static BookSourceStore? instance;

  final SharedPreferences preferences;
  final List<BookSourceConfig> _sources = [];
  List<BookSourceConfig> get sources => List.unmodifiable(_sources);
  List<BookSourceConfig> get enabledSources =>
      List.unmodifiable(_sources.where((source) => source.enabled));

  BookSourceConfig? byId(String id) {
    for (final source in _sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  Future<void> load() async {
    _sources.clear();
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.length > 20) {
        throw const FormatException();
      }
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final source = BookSourceConfig.fromJson(item);
        source.validate();
        if (_sources.any((entry) => entry.id == source.id)) continue;
        _sources.add(source);
      }
    } catch (_) {
      _sources.clear();
      throw const FormatException('书源配置损坏，请重新导入配置');
    }
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
  }) : _request = request ?? LegacyTransport.getSourceText;

  final BookSourceConfig source;
  final BookSourceTextRequest _request;

  Future<String> _fetch(String url) async {
    final uri = _resolvePage(url);
    if (uri == null) throw const FormatException('书源链接超出了配置的网站域名');
    return _request(uri.toString(), baseUrl: source.baseUrl);
  }

  Future<NovelPage> search(String keyword, {int page = 1}) async {
    if (page < 1 || page > 10000) {
      throw ArgumentError.value(page, 'page');
    }
    final url = source.searchUrlTemplate
        .replaceAll('{keyword}', Uri.encodeQueryComponent(keyword))
        .replaceAll('{page}', page.toString());
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
      final id = _stableId('\${source.id}|$bookUrl', 0x40000000);
      if (!seen.add(id)) continue;
      final author = _text(row, source.searchAuthorSelector);
      final summary = _text(row, source.searchSummarySelector);
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
          genre: source.name,
          summary: summary,
          colors: _colors(id),
          coverUrl: coverUrl,
          sourceId: source.id,
          sourceName: source.name,
          sourceUrl: bookUrl.toString(),
          sourceBaseUrl: source.baseUrl,
          sourceImageHosts: source.imageHosts,
        ),
      );
    }
    return NovelPage(
      items: List.unmodifiable(books),
      page: page,
      totalPages: null,
      totalItems: null,
    );
  }

  Future<Novel> detail(Novel seed) async {
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
      genre: genre.isEmpty ? source.name : genre,
      summary: summary.isEmpty ? seed.summary : summary,
      colors: seed.colors,
      isComplete: status.contains('完结') || status.contains('完本'),
      coverUrl: _resolveImage(cover) ?? seed.coverUrl,
      chapterCount: seed.chapterCount,
      sourceId: source.id,
      sourceName: source.name,
      sourceUrl: seed.sourceUrl,
      sourceBaseUrl: source.baseUrl,
      sourceImageHosts: source.imageHosts,
    );
  }

  Future<List<NovelChapter>> chapters(Novel novel) async {
    final bookUrl = novel.sourceUrl;
    if (bookUrl == null || bookUrl.isEmpty) {
      throw const FormatException('这本书缺少原始网站地址');
    }
    final rawUrl = source.chapterListUrlTemplate.trim().isEmpty
        ? bookUrl
        : source.chapterListUrlTemplate.replaceAll('{bookUrl}', bookUrl);
    final html = await _fetch(source.baseUri.resolve(rawUrl).toString());
    final document = parse(html);
    final rows = document.querySelectorAll(source.chapterItemSelector);
    final result = <NovelChapter>[];
    final seen = <int>{};
    for (final row in rows.take(5000)) {
      final titleNode = source.chapterTitleSelector.trim().isEmpty
          ? row
          : _query(row, source.chapterTitleSelector) ?? row;
      final linkNode = _linkNode(row, titleNode, source.chapterHrefSelector);
      final href = linkNode?.attributes['href'] ?? '';
      final chapterUrl = _resolvePage(href);
      final title = _clean(titleNode.text);
      if (title.isEmpty || chapterUrl == null) continue;
      final id = _stableId('\${source.id}|\${novel.id}|$chapterUrl', 0x20000000);
      if (!seen.add(id)) continue;
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
    if (result.isEmpty) {
      throw const FormatException('没有解析到目录，请检查目录 CSS 选择器和链接选择器');
    }
    return List.unmodifiable(result);
  }

  Future<String> chapterContent(NovelChapter chapter) async {
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
    final text = root.nodes.map(_flatten).join();
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
    final hostAllowed =
        resolved.host == base.host || source.imageHosts.contains(resolved.host);
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
  try {
    return title.closest('a[href]') ?? row.querySelector('a[href]');
  } catch (_) {
    return row.querySelector('a[href]');
  }
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

String _flatten(Node node) {
  if (node is Text) return node.text;
  if (node is! Element) return '';
  final tag = node.localName;
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
    'img',
    'svg',
    'ul',
    'ol',
  }.contains(tag)) {
    return '';
  }
  if (tag == 'br') return '\n';
  final content = node.nodes.map(_flatten).join();
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
    return '\n\n$content\n\n';
  }
  return content;
}
