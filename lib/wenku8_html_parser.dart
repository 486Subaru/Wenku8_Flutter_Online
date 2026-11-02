import 'package:flutter/material.dart' show Color;
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import 'catalog.dart';
import 'publication_catalog.dart';

class Wenku8BookDetail {
  const Wenku8BookDetail(this.book, this.novelPrefix);
  final Novel book;
  final String novelPrefix;
}

/// HTML parsing for the official Wenku8 pages. This intentionally consumes
/// only pages returned by the official-site transport; it does not mirror books.
abstract final class Wenku8HtmlParser {
  static const base = 'https://www.wenku8.net/';
  static const _imageHosts = {
    'img.wenku8.com',
    'pic.wenku8.com',
    'pic.wenku8.cn',
    'pic.wenku8.net',
  };
  static const _palettes = <List<Color>>[
    [Color(0xFF6D89A9), Color(0xFF263A58)],
    [Color(0xFFB37C80), Color(0xFF593D57)],
    [Color(0xFF6D9C94), Color(0xFF244F57)],
    [Color(0xFFB38D62), Color(0xFF574333)],
    [Color(0xFF887EB0), Color(0xFF39345F)],
  ];
  static const _stopLabels = [
    '小说作者',
    '文库分类',
    '文章状态',
    '最后更新',
    '最近章节',
    '作品Tags',
    '内容简介',
    '字数',
  ];

  static List<PublicationLibrary> parsePublicationLibraries(String source) {
    final document = parse(source);
    final found = <int, String>{0: '全部作品'};
    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'] ?? '';
      if (!href.contains('articlelist.php')) continue;
      final uri = _resolvePage(href);
      final id = int.tryParse(uri?.queryParameters['class'] ?? '');
      final name = _oneLine(anchor.text);
      if (id != null && id > 0 && name.isNotEmpty) found[id] = name;
    }
    final entries = found.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return List.unmodifiable([
      for (final entry in entries) PublicationLibrary(entry.key, entry.value),
    ]);
  }

  static NovelPage parseBookPage(String source, int page) {
    final document = parse(source);
    final items = parseBookList(source);
    final pages = _lastPage(document);
    return NovelPage(
      items: List.unmodifiable(items),
      page: page,
      totalPages: pages,
    );
  }

  static List<Novel> parseBookList(String source) {
    final document = parse(source);
    final seen = <int>{};
    final books = <Novel>[];
    for (final anchor in document.querySelectorAll('a[href]')) {
      final id = _bookId(anchor.attributes['href']);
      if (id == null) continue;
      // A live entry links to the same book twice: the first link wraps only
      // the cover and has no visible text. Do not mark its ID as seen until
      // the titled link is reached.
      final title = _cleanTitle(anchor.text);
      if (title.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      final entry = _entryFor(anchor);
      final text = _oneLine(entry.text);
      final author = _capture(
        text,
        RegExp(r'作者[:：]\s*(.+?)(?=分类[:：]|文库分类[:：]|更新[:：]|状态[:：]|字数[:：]|Tags[:：]|简介[:：]|$)'),
      ).split('/').first.trim();
      final category = _capture(
        text,
        RegExp(r'(?:分类|文库分类)[:：]\s*(.+?)(?=更新[:：]|状态[:：]|字数[:：]|Tags[:：]|简介[:：]|$)'),
      ).split('/').first.trim();
      final updated = _capture(
        text,
        RegExp(r'(?:更新|最后更新)[:：]\s*(\d{4}[-/]\d{1,2}[-/]\d{1,2})'),
      );
      final status = _capture(
        text,
        RegExp(r'(?:状态|文章状态)[:：]\s*(.+?)(?=作者[:：]|分类[:：]|更新[:：]|$)'),
      );
      final latest = _capture(
        text,
        RegExp(r'(?:最近章节|最新章节)[:：]\s*(.+?)(?=作者[:：]|分类[:：]|更新[:：]|$)'),
      );
      final summary = _capture(
        text,
        RegExp(r'(?:简介|内容简介)[:：]\s*(.+?)(?=作者[:：]|分类[:：]|更新[:：]|$)'),
      );
      final cover = _coverFromEntry(entry, id);
      final chapterCount = int.tryParse(
            RegExp(r'(\d+)\s*章').firstMatch(text)?.group(1) ?? '',
          ) ??
          0;
      books.add(
        Novel(
          id: id,
          title: title,
          author: author,
          genre: category.isEmpty ? '轻小说' : category,
          summary: summary.isEmpty ? latest : summary,
          colors: _colors(id),
          coverUrl: cover,
          lastUpdate: updated.isEmpty ? null : updated,
          chapterCount: chapterCount,
          isComplete: status.contains('完结') || status.contains('完本'),
        ),
      );
    }
    return List.unmodifiable(books);
  }

  static Wenku8BookDetail? parseBookDetail(
    String source,
    int bookId, {
    Novel? seed,
  }) {
    final document = parse(source);
    final root = document.querySelector('#content') ??
        document.body ??
        document.documentElement;
    if (root == null) return null;
    final pageTitle = _oneLine(document.querySelector('title')?.text ?? '');
    final heading = _oneLine(
      root.querySelector('h1')?.text ??
          root.querySelector('table tr td')?.text ??
          '',
    );
    final title = _cleanTitle(
      pageTitle.isNotEmpty ? pageTitle.split(RegExp(r'\s+-\s+')).first : heading,
    );
    final author = _labeledValue(root, '小说作者');
    final category = _labeledValue(root, '文库分类');
    final status = _labeledValue(root, '文章状态');
    final updated = _labeledValue(root, '最后更新');
    final intro = _labeledValue(root, '内容简介').ifEmpty(
      () => _labeledValue(root, '简介'),
    );
    final tags = _labeledValue(root, '作品Tags');
    final prefix = _novelPrefix(root, bookId);
    final cover = _detailCover(root) ?? _coverFromPrefix(prefix, bookId);
    final text = _oneLine(root.text);
    final chapterCount = int.tryParse(
          RegExp(r'(\d+)\s*章').firstMatch(text)?.group(1) ?? '',
        ) ??
        seed?.chapterCount ??
        0;
    final resolvedTitle = title.isNotEmpty ? title : seed?.title ?? '';
    if (resolvedTitle.isEmpty) return null;
    final genre = [category, tags]
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final book = Novel(
      id: bookId,
      title: resolvedTitle,
      author: author.isNotEmpty ? author : seed?.author ?? '',
      genre: genre.isNotEmpty ? genre : seed?.genre ?? '轻小说',
      summary: intro.isNotEmpty ? intro : seed?.summary ?? '',
      colors: seed?.colors ?? _colors(bookId),
      chapters: seed?.chapters ?? const [],
      isComplete: status.contains('完结') ||
          status.contains('完本') ||
          seed?.isComplete == true,
      coverUrl: cover ?? seed?.coverUrl,
      lastUpdate: updated.isNotEmpty ? updated : seed?.lastUpdate,
      chapterCount: chapterCount,
    );
    return Wenku8BookDetail(book, prefix);
  }

  static List<NovelChapter> parseChapterList(String source) {
    final document = parse(source);
    final chapters = <NovelChapter>[];
    final seen = <int>{};
    var volumeId = 0;
    var volumeTitle = '';
    final tables = document.querySelectorAll('table');
    final table = tables.firstWhere(
      (candidate) => candidate.querySelector('td.ccss a[href]') != null,
      orElse: () => tables.firstWhere(
        (candidate) => candidate.querySelector('a[href]') != null,
        orElse: () => document.createElement('table'),
      ),
    );
    for (final row in table.querySelectorAll('tr')) {
        final volume = row.querySelector('td.vcss');
        if (volume != null) {
          volumeId++;
          volumeTitle = _oneLine(volume.text);
        }
        for (final cell in row.querySelectorAll('td.ccss')) {
          for (final anchor in cell.querySelectorAll('a[href]')) {
            final id = _chapterId(anchor.attributes['href']);
            if (id == null || !seen.add(id)) continue;
            final title = _oneLine(anchor.text);
            chapters.add(
              NovelChapter(
                title.isEmpty ? '第 $id 章' : title,
                '',
                id: id,
                volumeId: volumeId,
                volumeTitle: volumeTitle,
              ),
            );
          }
        }
      }
    if (chapters.isEmpty) {
      for (final anchor in document.querySelectorAll('a[href]')) {
        final id = _chapterId(anchor.attributes['href']);
        if (id == null || !seen.add(id)) continue;
        final title = _oneLine(anchor.text);
        if (title.isEmpty) continue;
        chapters.add(NovelChapter(title, '', id: id));
      }
    }
    return List.unmodifiable(chapters);
  }

  static String parseChapterBody(String source, String chapterUrl) {
    final document = parse(source);
    final root = document.querySelector('#content') ?? document.body;
    if (root == null) throw const FormatException('章节页面结构无效');
    for (final element in root.querySelectorAll(
      'ul#contentdp, script, style, noscript, iframe, form',
    )) {
      element.remove();
    }
    final baseUri = Uri.tryParse(chapterUrl) ?? Uri.parse(base);
    final body = root.nodes.map((node) => _flatten(node, baseUri)).join();
    final normalized = body
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

  static String _flatten(Node node, Uri baseUri) {
    if (node is Text) return node.text;
    if (node is! Element) return '';
    final tag = node.localName;
    if (const {
      'script',
      'style',
      'noscript',
      'iframe',
      'form',
      'ul',
      'ol',
    }.contains(tag)) {
      return '';
    }
    if (tag == 'img') {
      final url = _absoluteImageUrl(node.attributes['src'], baseUri);
      return url == null ? '' : '\n\n<!--image-->$url<!--image-->\n\n';
    }
    if (tag == 'br') return '\n';
    final content = node.nodes.map((child) => _flatten(child, baseUri)).join();
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

  static String _labeledValue(Element root, String label) {
    final candidates = root
        .querySelectorAll('td, span, b, strong, p, div')
        .where((element) => element.text.contains(label))
        .toList()
      ..sort((a, b) => a.text.length.compareTo(b.text.length));
    for (final element in candidates) {
      final raw = _oneLine(element.text);
      final index = raw.indexOf(label);
      if (index < 0) continue;
      var value = raw.substring(index + label.length).trimLeft();
      value = value.replaceFirst(RegExp(r'^[:：\s]+'), '');
      value = _trimAtLabels(value);
      if (value.isNotEmpty) return value;
      final sibling = element.nextElementSibling;
      if (sibling != null) {
        final next = _trimAtLabels(_oneLine(sibling.text));
        if (next.isNotEmpty) return next;
      }
    }
    return '';
  }

  static String _trimAtLabels(String value) {
    var end = value.length;
    for (final label in _stopLabels) {
      final index = value.indexOf(label);
      if (index > 0 && index < end) end = index;
    }
    return value.substring(0, end).trim();
  }

  static Element _entryFor(Element anchor) {
    Element current = anchor;
    Element? textFallback;
    for (var depth = 0; depth < 7; depth++) {
      final parent = current.parentNode;
      if (parent is! Element) break;
      current = parent;
      final tag = current.localName;
      if (tag != 'div' && tag != 'td' && tag != 'li') continue;
      if (textFallback == null &&
          current.text.trim().length > anchor.text.trim().length + 12) {
        textFallback = current;
      }
      // Prefer the nearest ancestor that contains both the title and cover.
      // The immediately enclosing info div often has author text but no image.
      if (current.querySelector('img') != null) return current;
    }
    return textFallback ??
        (anchor.parentNode is Element ? anchor.parentNode as Element : anchor);
  }

  static String? _detailCover(Element root) {
    for (final image in root.querySelectorAll('img[src]')) {
      final url = _absoluteImageUrl(image.attributes['src'], Uri.parse(base));
      if (url != null && url.contains('/image/')) return url;
    }
    return null;
  }

  static String? _coverFromEntry(Element entry, int id) {
    final images = entry.querySelectorAll('img[src]');
    for (final image in images) {
      final parent = image.parentNode;
      if (parent is Element &&
          _bookId(parent.attributes['href']) == id) {
        final url = _absoluteImageUrl(image.attributes['src'], Uri.parse(base));
        if (url != null) return url;
      }
    }
    for (final image in images) {
      final url = _absoluteImageUrl(image.attributes['src'], Uri.parse(base));
      if (url != null) return url;
    }
    for (final anchor in entry.querySelectorAll('a[href]')) {
      final prefix = _novelPrefixFromUrl(anchor.attributes['href'], id);
      if (prefix.isNotEmpty) return _coverFromPrefix(prefix, id);
    }
    return null;
  }

  static String? _coverFromPrefix(String prefix, int id) {
    final match = RegExp(r'^/novel/(\d+)/').firstMatch(prefix);
    if (match == null) return null;
    return 'https://img.wenku8.com/image/' +
        match.group(1)! +
        '/$id/' +
        id.toString() +
        's.jpg';
  }

  static String _novelPrefix(Element root, int id) {
    for (final anchor in root.querySelectorAll('a[href]')) {
      final prefix = _novelPrefixFromUrl(anchor.attributes['href'], id);
      if (prefix.isNotEmpty) return prefix;
    }
    return '';
  }

  static String _novelPrefixFromUrl(String? raw, int id) {
    if (raw == null || raw.isEmpty) return '';
    final uri = _resolvePage(raw);
    if (uri == null) return '';
    final match = RegExp(
      '/novel/(\\d+)/' + id.toString() + r'/(?:index|\d+)\.htm$',
    ).firstMatch(uri.path);
    return match == null ? '' : '/novel/' + match.group(1)! + '/$id/';
  }

  static String? _absoluteImageUrl(String? raw, Uri baseUri) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    var resolved = uri.hasScheme ? uri : baseUri.resolveUri(uri);
    const officialHosts = {'www.wenku8.net', 'wenku8.net'};
    if (resolved.scheme == 'http' &&
        (_imageHosts.contains(resolved.host) ||
            officialHosts.contains(resolved.host))) {
      resolved = resolved.replace(scheme: 'https', port: null);
    }
    final imageHost = _imageHosts.contains(resolved.host) &&
        RegExp(
          r'^/(?:image|pictures|illustrations)/[A-Za-z0-9_./-]+\.(?:jpe?g|png|gif|webp)$',
          caseSensitive: false,
        ).hasMatch(resolved.path);
    final officialPicture = officialHosts.contains(resolved.host) &&
        RegExp(
          r'^/(?:pictures|illustrations)/[A-Za-z0-9_./-]+\.(?:jpe?g|png|gif|webp)$',
          caseSensitive: false,
        ).hasMatch(resolved.path);
    if (resolved.scheme != 'https' ||
        !(imageHost || officialPicture) ||
        resolved.userInfo.isNotEmpty ||
        resolved.hasPort && resolved.port != 443 ||
        resolved.hasQuery ||
        resolved.hasFragment ||
        resolved.pathSegments.contains('..')) {
      return null;
    }
    return resolved.toString();
  }

  static Uri? _resolvePage(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    var resolved = uri.hasScheme ? uri : Uri.parse(base).resolveUri(uri);
    if (resolved.scheme == 'http' &&
        const {'www.wenku8.net', 'wenku8.net'}.contains(resolved.host)) {
      resolved = resolved.replace(scheme: 'https', port: 443);
    }
    if (resolved.scheme != 'https' ||
        !const {'www.wenku8.net', 'wenku8.net'}.contains(resolved.host) ||
        resolved.userInfo.isNotEmpty ||
        resolved.hasPort && resolved.port != 443) {
      return null;
    }
    return resolved;
  }

  static int? _bookId(String? raw) {
    if (raw == null) return null;
    final uri = _resolvePage(raw);
    final path = uri?.path ?? raw;
    return int.tryParse(
      RegExp(r'/book/(\d+)\.htm').firstMatch(path)?.group(1) ?? '',
    );
  }

  static int? _chapterId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    final path = uri?.path ?? raw.split('?').first.split('#').first;
    final match = RegExp(r'(?:^|/)(\d+)\.htm$').firstMatch(path);
    return int.tryParse(match?.group(1) ?? '');
  }

  static int? _lastPage(Document document) {
    var last = 0;
    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'] ?? '';
      final uri = _resolvePage(href);
      final page = int.tryParse(uri?.queryParameters['page'] ?? '');
      if (page != null && page > last) last = page;
    }
    return last == 0 ? null : last;
  }

  static String _cleanTitle(String raw) {
    var title = _oneLine(raw).split('小说在线阅读').first;
    if (title.contains('《') && title.contains('》')) {
      title = title.substring(title.indexOf('《') + 1, title.indexOf('》'));
    }
    title = title
        .replaceAll(RegExp(r'\s*-\s*轻小说文库\s*$'), '')
        .replaceAll(RegExp(r'\s*[-–—]\s*最新最全.*$'), '')
        .replaceAll(RegExp(r'\[[^\]]*]'), '')
        .trim();
    return title;
  }

  static String _capture(String text, RegExp pattern) =>
      pattern.firstMatch(text)?.group(1)?.trim() ?? '';

  static String _oneLine(String value) =>
      value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<Color> _colors(int id) =>
      _palettes[id.abs() % _palettes.length];
}

extension _NonEmptyString on String {
  String ifEmpty(String Function() fallback) =>
      isEmpty ? fallback() : this;
}
