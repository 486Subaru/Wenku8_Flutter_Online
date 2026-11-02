import 'book_search.dart';
import 'catalog.dart';
import 'legacy_transport.dart';
import 'online_component.dart';
import 'publication_catalog.dart';
import 'tag_catalogue.dart';
import 'wenku8_html_parser.dart';

typedef _WenkuPageRequest = Future<String> Function(
  String url, {
  String? referer,
});
typedef _WenkuSearchRequest = Future<String> Function(
  String query, {
  String field,
  int page,
});

/// Official-site repository. It reads pages through the Android WebView-backed
/// transport and never downloads or exports whole-book files.
class LegacyWenkuRepository extends NovelRepository
    implements PublicationCatalog, ProgressiveTagCatalogue {
  LegacyWenkuRepository({
    _WenkuPageRequest? request,
    _WenkuSearchRequest? searchRequest,
  }) : _request = request ?? LegacyTransport.getText,
       _searchRequest = searchRequest ?? LegacyTransport.search;

  static const _base = Wenku8HtmlParser.base;
  final _WenkuPageRequest _request;
  final _WenkuSearchRequest _searchRequest;

  final Map<(NovelSort, int), NovelPage> _pages = {};
  final Map<(NovelSort, int), Future<NovelPage>> _pendingPages = {};
  final Map<(int, int), NovelPage> _publicationPages = {};
  final Map<(int, int), Future<NovelPage>> _pendingPublicationPages = {};
  final Map<int, Novel> _details = {};
  final Map<int, String> _novelPrefixes = {};
  Future<List<PublicationLibrary>>? _libraries;

  @override
  Future<List<Novel>> list() async =>
      (await browse(sort: NovelSort.lastUpdate)).items;

  @override
  Future<Novel?> find(int id) async {
    if (id <= 0) return null;
    try {
      return (await _loadDetail(id)).book;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<List<Novel>> search(String query) async =>
      (await searchFilteredPage(query)).items;

  @override
  Future<Novel> detail(Novel novel) async =>
      (await _loadDetail(novel.id, seed: novel)).book;

  @override
  Future<List<NovelChapter>> chapters(int id) async {
    if (id <= 0) throw ArgumentError.value(id, 'id');
    var prefix = _novelPrefixes[id];
    if (prefix == null || prefix.isEmpty) {
      await _loadDetail(id);
      prefix = _novelPrefixes[id];
    }
    if (prefix == null || prefix.isEmpty) {
      throw const FormatException('官网没有提供这本书的目录地址');
    }
    final url = _base + prefix + 'index.htm';
    final source = await _request(url, referer: _detailUrl(id));
    final result = Wenku8HtmlParser.parseChapterList(source);
    if (result.isEmpty) throw const FormatException('官网目录为空或页面结构已变化');
    return result;
  }

  @override
  Future<String> chapterContent(int novelId, NovelChapter chapter) async {
    if (novelId <= 0 || chapter.id <= 0) {
      throw ArgumentError('Invalid novel or chapter ID');
    }
    var prefix = _novelPrefixes[novelId];
    if (prefix == null || prefix.isEmpty) {
      await _loadDetail(novelId);
      prefix = _novelPrefixes[novelId];
    }
    if (prefix == null || prefix.isEmpty) {
      throw const FormatException('官网没有提供这本书的章节地址');
    }
    final url = _base + prefix + chapter.id.toString() + '.htm';
    final source = await _request(
      url,
      referer: _base + prefix + 'index.htm',
    );
    return Wenku8HtmlParser.parseChapterBody(source, url);
  }

  @override
  Future<NovelPage> browse({
    NovelSort sort = NovelSort.lastUpdate,
    int page = 1,
    bool refresh = false,
  }) {
    if (page < 1 || page > 100000) {
      throw ArgumentError.value(page, 'page');
    }
    final key = (sort, page);
    if (refresh) {
      _pages.remove(key);
      _pendingPages.remove(key);
    }
    final cached = _pages[key];
    if (cached != null) return Future.value(cached);
    final pending = _pendingPages[key];
    if (pending != null) return pending;
    final future = _loadBrowse(sort, page);
    _pendingPages[key] = future;
    return future.whenComplete(() => _pendingPages.remove(key));
  }

  Future<NovelPage> _loadBrowse(NovelSort sort, int page) async {
    final url = sort == NovelSort.fullFlag
        ? _base + 'modules/article/articlelist.php?fullflag=1&page=' + page.toString()
        : _base +
            'modules/article/toplist.php?sort=' +
            sort.apiKey +
            '&page=' +
            page.toString();
    final source = await _request(url, referer: _base + 'index.php');
    final result = Wenku8HtmlParser.parseBookPage(source, page);
    _pages[(sort, page)] = result;
    return result;
  }

  @override
  Future<NovelPage> searchPage(
    String query, {
    int page = 1,
    bool refresh = false,
  }) => searchFilteredPage(
    query,
    field: BookSearchField.all,
    page: page,
    refresh: refresh,
  );

  @override
  Future<NovelPage> searchFilteredPage(
    String query, {
    BookSearchField field = BookSearchField.all,
    int page = 1,
    bool refresh = false,
  }) async {
    final term = query.trim();
    if (term.isEmpty) {
      return NovelPage(items: const [], page: page, totalPages: 0);
    }
    if (page < 1 || page > 100000) {
      throw ArgumentError.value(page, 'page');
    }
    if (field == BookSearchField.id) {
      final id = int.tryParse(term);
      if (id == null || id <= 0 || page > 1) {
        return NovelPage(items: const [], page: page, totalPages: 0);
      }
      final book = await find(id);
      return NovelPage(
        items: book == null ? const [] : [book],
        page: page,
        totalPages: book == null ? 0 : 1,
        totalItems: book == null ? 0 : 1,
      );
    }

    if (field == BookSearchField.title) {
      return _searchPage(term, 'articlename', page);
    }
    if (field == BookSearchField.author) {
      return _searchPage(term, 'author', page);
    }
    if (field == BookSearchField.tags) {
      final source = await _searchPage(term, 'articlename', page);
      final pattern = BookSearch(term, field: BookSearchField.tags);
      final filtered = source.items.where((book) => pattern.matches(
        title: book.title,
        author: book.author,
        tags: book.genre,
        summary: book.summary,
        id: book.id.toString(),
      )).toList();
      return NovelPage(
        items: List.unmodifiable(filtered),
        page: page,
        totalPages: source.totalPages,
        totalItems: filtered.length,
      );
    }

    final byTitle = await _searchPage(term, 'articlename', page);
    final byAuthor = await _searchPage(term, 'author', page);
    final unique = <int, Novel>{
      for (final book in byTitle.items) book.id: book,
      for (final book in byAuthor.items) book.id: book,
    };
    final items = unique.values.toList();
    return NovelPage(
      items: List.unmodifiable(items),
      page: page,
      totalPages: _maxPages(byTitle.totalPages, byAuthor.totalPages),
      totalItems: items.length,
    );
  }

  Future<NovelPage> _searchPage(String query, String field, int page) async {
    final source = await _searchRequest(query, field: field, page: page);
    return Wenku8HtmlParser.parseBookPage(source, page);
  }

  @override
  Future<List<PublicationLibrary>> publicationLibraries({
    bool refresh = false,
  }) async {
    if (refresh) _libraries = null;
    final cached = _libraries;
    if (cached != null) return cached;
    final future = () async {
      try {
        final source = await _request(_base + 'index.php');
        return Wenku8HtmlParser.parsePublicationLibraries(source);
      } catch (_) {
        _libraries = null;
        rethrow;
      }
    }();
    _libraries = future;
    return future;
  }

  @override
  Future<NovelPage> browsePublication(
    int libraryId, {
    int page = 1,
    bool refresh = false,
  }) {
    if (libraryId < 0 || page < 1 || page > 100000) {
      throw ArgumentError('Invalid publication page');
    }
    final key = (libraryId, page);
    if (refresh) {
      _publicationPages.remove(key);
      _pendingPublicationPages.remove(key);
    }
    final cached = _publicationPages[key];
    if (cached != null) return Future.value(cached);
    final pending = _pendingPublicationPages[key];
    if (pending != null) return pending;
    final future = _loadPublication(libraryId, page);
    _pendingPublicationPages[key] = future;
    return future.whenComplete(() => _pendingPublicationPages.remove(key));
  }

  Future<NovelPage> _loadPublication(int libraryId, int page) async {
    final url = libraryId == 0
        ? _base + 'modules/article/toplist.php?sort=lastupdate&page=' + page.toString()
        : _base + 'modules/article/articlelist.php?class=' +
            libraryId.toString() + '&page=' + page.toString();
    final source = await _request(url, referer: _base + 'index.php');
    final result = Wenku8HtmlParser.parseBookPage(source, page);
    _publicationPages[(libraryId, page)] = result;
    return result;
  }

  @override
  Future<NovelPage> tagPage(
    String tag, {
    int page = 1,
    bool refresh = false,
    bool Function()? current,
    void Function(TagSearchProgress)? onProgress,
  }) async {
    final term = tag.trim().replaceFirst(RegExp(r'^#+'), '');
    if (term.isEmpty) {
      return NovelPage(items: const [], page: page, totalPages: 0);
    }
    if (current != null && !current()) {
      return NovelPage(items: const [], page: page, totalPages: 0);
    }
    final source = await _searchPage(term, 'articlename', page);
    final pattern = BookSearch(term, field: BookSearchField.tags);
    final items = source.items.where((book) => pattern.matches(
      title: book.title,
      author: book.author,
      tags: book.genre,
      summary: book.summary,
      id: book.id.toString(),
    )).toList();
    final result = NovelPage(
      items: List.unmodifiable(items),
      page: page,
      totalPages: source.totalPages,
      totalItems: items.length,
    );
    onProgress?.call(
      TagSearchProgress(
        items: result.items,
        scannedPages: page,
        totalPages: result.totalPages,
      ),
    );
    return result;
  }

  Future<Wenku8BookDetail> _loadDetail(int id, {Novel? seed}) async {
    final cached = _details[id];
    if (cached != null && seed == null &&
        (_novelPrefixes[id]?.isNotEmpty ?? false)) {
      return Wenku8BookDetail(cached, _novelPrefixes[id] ?? '');
    }
    final source = await _request(_detailUrl(id), referer: _base + 'index.php');
    final parsed = Wenku8HtmlParser.parseBookDetail(source, id, seed: seed);
    if (parsed == null) throw const FormatException('官网没有返回有效的书籍详情');
    _details[id] = parsed.book;
    if (parsed.novelPrefix.isNotEmpty) {
      _novelPrefixes[id] = parsed.novelPrefix;
    }
    return parsed;
  }

  String _detailUrl(int id) => _base + 'book/' + id.toString() + '.htm';

  int? _maxPages(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }
}
