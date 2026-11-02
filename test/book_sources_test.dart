import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/book_search.dart';
import 'package:wenku8_flutter/legacy_wenku_repository.dart';

import 'package:wenku8_flutter/book_sources.dart';

void main() {
  group('BookSourceConfig', () {
    test('rejects non-HTTPS site origins and missing page placeholders', () {
      final config = _config(baseUrl: 'http://source.example/');
      expect(config.validate, throwsFormatException);

      final missingPage = _config(
        searchUrlTemplate: 'https://source.example/search?q={keyword}',
      );
      expect(missingPage.validate, throwsFormatException);
    });

    test('rejects wildcard request hosts and accepts explicit login hosts', () {
      expect(_config(requestHosts: const ['*.api.source.example']).validate, throwsFormatException);
      expect(
        _config(loginUrl: 'https://auth.source.example/login', loginHosts: const ['auth.source.example']).validate,
        returnsNormally,
      );
    });

    test('rejects wildcard login redirect hosts', () {
      final config = _config(
        loginUrl: '/login',
        loginHosts: const ['*.source.example'],
      );
      expect(config.validate, throwsFormatException);
    });

    test('round trips its JSON configuration', () {
      final config = _config(
        loginUrl: '/login',
        loginHosts: const ['auth.source.example'],
        requestHosts: const ['api.source.example'],
        browseUrlTemplate: '/latest?page={page}',
        imageHosts: const ['cdn.source.example'],
      );
      final restored = BookSourceConfig.fromJson(Map<String, dynamic>.from(config.toJson()));
      restored.validate();
      expect(restored.id, config.id);
      expect(restored.loginUrl, '/login');
      expect(restored.loginHosts, ['auth.source.example']);
      expect(restored.requestHosts, ['api.source.example']);
      expect(restored.browseUrlTemplate, '/latest?page={page}');
      expect(restored.imageHosts, ['cdn.source.example']);
    });
  });

  test('offers built-in login presets and keeps browser-only sites off the reader', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);

    expect(
      store.loginOptions.map((source) => source.id),
      containsAll([
        'lightnovel-fun',
        'linovelib-web',
        'esjzone-web',
        'linovel-net-web',
      ]),
    );

    final readerSource = await store.installPreset('lightnovel-fun');
    expect(readerSource.supportsReading, isTrue);
    expect(readerSource.loginHosts, contains('lightnovel.fun'));
    expect(readerSource.requestHosts, contains('lightnovel.fun'));
    await store.setLoginSourceId(readerSource.id);
    expect(store.homepageSourceId, isNull);

    final browserOnly = await store.installPreset('linovelib-web');
    expect(browserOnly.supportsReading, isFalse);
    await store.setLoginSourceId(browserOnly.id);
    expect(store.loginSourceId, browserOnly.id);
    expect(store.homepageSourceId, isNull);
    expect(
      store.enabledSources.map((source) => source.id),
      isNot(contains(browserOnly.id)),
    );

    await expectLater(
      BookSourceRepository(browserOnly).search('测试'),
      throwsFormatException,
    );
  });

  test('persists custom source configurations across app starts', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = BookSourceStore(preferences);
    await first.save(_config());
    final second = BookSourceStore(preferences);
    await second.load();
    expect(second.sources, hasLength(1));
    expect(second.sources.single.id, 'test-source');
    expect(second.enabledSources, hasLength(1));
  });

  test('reader-capable login source defaults to homepage while accounts stay isolated', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);
    await store.save(_config(loginUrl: '/login'));
    await store.installPreset('lightnovel-fun');

    await store.setLoginSourceId('lightnovel-fun');
    expect(store.loginSourceId, 'lightnovel-fun');
    expect(store.homepageSourceId, 'lightnovel-fun');
    expect(store.isSourceLoggedIn('lightnovel-fun'), isFalse);

    await store.completeSourceLogin('lightnovel-fun');
    expect(store.isSourceLoggedIn('lightnovel-fun'), isTrue);
    expect(store.homepageSourceId, 'lightnovel-fun');

    // A manual homepage choice remains possible after the default sync.
    await store.setHomepageSourceId('test-source');
    expect(store.homepageSourceId, 'test-source');

    // Switching back to the official Wenku8 login restores the official homepage.
    await store.setLoginSourceId(null);
    expect(store.loginSourceId, isNull);
    expect(store.homepageSourceId, isNull);
    expect(store.isSourceLoggedIn('lightnovel-fun'), isTrue);
    await store.completeOfficialLogin();
    expect(store.homepageSourceId, isNull);
  });

  test('web-login-only source does not replace the readable homepage source', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);
    await store.save(_config());
    await store.installPreset('linovelib-web');
    await store.setHomepageSourceId('test-source');
    await store.setLoginSourceId('linovelib-web');
    expect(store.homepageSourceId, 'test-source');
  });

  test('preserves a selected homepage while revalidating old login state', () async {
    SharedPreferences.setMockInitialValues({
      BookSourceStore.preferenceKey: jsonEncode([
        BookSourceStore.builtInPresets.first.toJson(),
      ]),
      BookSourceStore.homepageSourcePreferenceKey: 'lightnovel-fun',
      BookSourceStore.loginSourcePreferenceKey: 'lightnovel-fun',
      BookSourceStore.loggedInSourcesPreferenceKey: ['lightnovel-fun'],
    });
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);

    await store.load();
    expect(store.homepageSourceId, 'lightnovel-fun');
    expect(store.isSourceLoggedIn('lightnovel-fun'), isFalse);
    expect(
      preferences.getBool(BookSourceStore.loginHomepageSeparationMigrationKey),
      isTrue,
    );
  });

  test('restores a reader-capable login source after the old separation migration', () async {
    SharedPreferences.setMockInitialValues({
      BookSourceStore.preferenceKey: jsonEncode([
        BookSourceStore.builtInPresets.first.toJson(),
      ]),
      BookSourceStore.loginSourcePreferenceKey: 'lightnovel-fun',
      BookSourceStore.loginHomepageSeparationMigrationKey: true,
    });
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);

    await store.load();
    expect(store.homepageSourceId, 'lightnovel-fun');
    expect(
      preferences.getBool(BookSourceStore.loginHomepageSyncMigrationKey),
      isTrue,
    );
  });

  test('homepage source can be selected independently in settings', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);
    await store.save(_config());

    await store.setHomepageSourceId('test-source');
    expect(store.homepageSource?.id, 'test-source');
    await store.setHomepageSourceId(null);
    expect(store.homepageSourceId, isNull);
  });

  test('keeps search usable when the primary Wenku8 site is unavailable', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);
    final repository = LegacyWenkuRepository(
      bookSources: store,
      searchRequest: (
        String query, {
        String field = 'articlename',
        int page = 1,
      }) async {
        throw StateError('primary site unavailable');
      },
    );

    final result = await repository.searchFilteredPage('Novel');
    expect(result.items, isEmpty);
    expect(result.searchFailures, contains(BookSearchField.all));
  });

  test('parses search, detail, table of contents and chapter images', () async {
    final config = _config(
      loginUrl: '/login',
      searchUrlTemplate: '/search?q={keyword}&page={page}',
      searchItemSelector: '.book-result',
      searchTitleSelector: 'a.title',
      searchAuthorSelector: '.author',
      searchCoverSelector: 'img.cover',
      detailTitleSelector: 'h1.title',
      detailAuthorSelector: '.detail-author',
      detailSummarySelector: '.summary',
      detailGenreSelector: '.genre',
      detailStatusSelector: '.status',
      detailCoverSelector: 'img.detail-cover',
      chapterItemSelector: '#chapters a',
      chapterContentSelector: '#content',
      imageHosts: const ['cdn.source.example'],
    );
    final requests = <String>[];
    final responses = <String, String>{
      'https://source.example/search?q=Novel&page=1': '''
        <div class="book-result">
          <a class="title" href="/book/12">Sample Novel</a>
          <span class="author">A. Writer</span>
          <img class="cover" data-src="https://cdn.source.example/cover.jpg">
        </div>
      ''',
      'https://source.example/book/12': '''
        <h1 class="title">Sample Novel · Full</h1>
        <span class="detail-author">A. Writer</span>
        <div class="summary">A short description.</div>
        <div class="genre">Fantasy</div>
        <div class="status">已完结</div>
        <img class="detail-cover" src="https://cdn.source.example/detail.jpg">
        <div id="chapters"><a href="/chapter/1">Chapter One</a></div>
      ''',
      'https://source.example/chapter/1': '''
        <div id="content">
          <p>First paragraph.</p>
          <p>Second paragraph.</p>
          <img src="https://cdn.source.example/illustration.jpg">
        </div>
      ''',
    };
    final repository = BookSourceRepository(
      config,
      request: (url, {required baseUrl, required requestHosts}) async {
        expect(baseUrl, config.baseUrl);
        expect(requestHosts, config.requestHosts);
        requests.add(url);
        final response = responses[url];
        if (response == null) throw StateError('Unexpected URL: $url');
        return response;
      },
    );

    final page = await repository.search('Novel');
    expect(page.items, hasLength(1));
    final seed = page.items.single;
    expect(seed.title, 'Sample Novel');
    expect(seed.author, 'A. Writer');
    expect(seed.sourceId, config.id);
    expect(seed.sourceUrl, 'https://source.example/book/12');
    expect(seed.coverUrl, 'https://cdn.source.example/cover.jpg');

    final detail = await repository.detail(seed);
    expect(detail.title, 'Sample Novel · Full');
    expect(detail.genre, 'Fantasy');
    expect(detail.isComplete, isTrue);
    expect(detail.coverUrl, 'https://cdn.source.example/detail.jpg');

    final chapters = await repository.chapters(detail);
    expect(chapters, hasLength(1));
    expect(chapters.single.sourceId, config.id);
    expect(chapters.single.sourceUrl, 'https://source.example/chapter/1');

    final body = await repository.chapterContent(chapters.single);
    expect(body, contains('First paragraph.'));
    expect(body, contains('Second paragraph.'));
    expect(
      body,
      contains('<!--image-->https://cdn.source.example/illustration.jpg<!--image-->'),
    );
    expect(requests, hasLength(4));
  });


  test('uses the Light Novel Kingdom API adapter for search, detail, TOC and body', () async {
    final config = BookSourceConfig(
      id: 'lightnovel-fun',
      name: '轻之国度',
      baseUrl: 'https://www.lightnovel.fun/',
      engine: 'lightnovel_fun',
      loginUrl: '/',
      searchUrlTemplate: '',
      searchItemSelector: '',
      searchTitleSelector: '',
      chapterItemSelector: '',
      chapterContentSelector: '',
      imageHosts: const ['lightnovel.fun'],
      requestHosts: const ['lightnovel.fun'],
      enabled: false,
    );
    config.validate();
    final requests = <String>[];
    final responses = <String, String>{
      '/api/pc-proxy/api/new-content-read/get-book-detail': '''
        {"code":0,"data":{"title":"示例轻小说","author_name":"测试作者","summary_short":"作品简介","tags":["异世界"],"cover_url":"https://cdn.lightnovel.fun/cover.jpg","work_type":{"text":"轻小说"}}}
      ''',
      '/api/pc-proxy/api/new-content-read/get-book-volumes': '''
        {"code":0,"data":{"list":[{"volume_id":11,"title":"第一卷","chapter_count":1}],"pagination":{"page_count":1,"total":1}}}
      ''',
      '/api/pc-proxy/api/new-content-read/get-volume-chapters': '''
        {"code":0,"data":{"list":[{"chapter_id":22,"title":"第一章"}],"pagination":{"page_count":1,"total":1}}}
      ''',
      '/api/pc-proxy/api/new-content-read/get-chapter-detail': '''
        {"code":0,"data":{"body_snapshot":{"body_html":"<p>第一段正文。</p><p>第二段正文。</p>","body_text":"第一段正文。\\n第二段正文。"}}}
      ''',
    };
    final repository = BookSourceRepository(
      config,
      lightNovelSearchRequest: (
        String query, {
        required String baseUrl,
        required int page,
        required List<String> requestHosts,
      }) async {
        expect(baseUrl, config.baseUrl);
        expect(requestHosts, config.requestHosts);
        expect(page, 1);
        if (query.isEmpty) {
          return '''{"code":0,"data":{"collections":[{"sid":124,"name":"首页推荐作品","author":"首页作者","cover":"https://cdn.lightnovel.fun/home.jpg"}],"articles":[]}}''';
        }
        expect(query, '示例');
        return '''
          {"code":0,"data":{"collections":[{"sid":123,"name":"示例轻小说","author":"测试作者","cover":"https://cdn.lightnovel.fun/cover.jpg","group_name":"轻小说"}],"articles":[]}}
        ''';
      },
      jsonRequest: (url, {required baseUrl, required body, required requestHosts}) async {
        expect(baseUrl, config.baseUrl);
        expect(requestHosts, config.requestHosts);
        requests.add(Uri.parse(url).path);
        final response = responses[Uri.parse(url).path];
        if (response == null) throw StateError('Unexpected API: $url');
        return response;
      },
    );

    final home = await repository.browse();
    expect(home.items, hasLength(1));
    expect(home.items.single.title, '首页推荐作品');

    final page = await repository.search('示例');
    expect(page.items, hasLength(1));
    final seed = page.items.single;
    expect(seed.title, '示例轻小说');
    expect(seed.sourceUrl, 'https://www.lightnovel.fun/cn/series/123');

    final detail = await repository.detail(seed);
    expect(detail.author, '测试作者');
    expect(detail.summary, '作品简介');
    expect(detail.genre, '异世界');
    expect(detail.coverUrl, 'https://cdn.lightnovel.fun/cover.jpg');

    final chapters = await repository.chapters(detail);
    expect(chapters, hasLength(1));
    expect(chapters.single.title, '第一章');
    expect(chapters.single.volumeTitle, '第一卷');
    expect(chapters.single.sourceUrl, 'https://www.lightnovel.fun/cn/detail/22?book_id=123');

    final body = await repository.chapterContent(chapters.single);
    expect(body, contains('第一段正文。'));
    expect(body, contains('第二段正文。'));
    expect(requests, [
      '/api/pc-proxy/api/new-content-read/get-book-detail',
      '/api/pc-proxy/api/new-content-read/get-book-volumes',
      '/api/pc-proxy/api/new-content-read/get-volume-chapters',
      '/api/pc-proxy/api/new-content-read/get-chapter-detail',
    ]);
  });

  test('uses a separate browse URL template for the homepage', () async {
    final config = _config(browseUrlTemplate: '/latest?page={page}');
    final repository = BookSourceRepository(
      config,
      request: (url, {required baseUrl, required requestHosts}) async {
        expect(baseUrl, config.baseUrl);
        expect(requestHosts, config.requestHosts);
        expect(url, 'https://source.example/latest?page=2');
        return '''
          <div class="book-result">
            <a class="title" href="/book/88">Latest Novel</a>
          </div>
        ''';
      },
    );
    final result = await repository.browse(page: 2);
    expect(result.page, 2);
    expect(result.items.single.title, 'Latest Novel');
  });

  test('allows configured API hosts and blocks unconfigured hosts', () async {
    final config = _config(
      searchUrlTemplate: 'https://api.source.example/search?q={keyword}&page={page}',
      requestHosts: const ['api.source.example'],
    );
    final repository = BookSourceRepository(
      config,
      request: (url, {required baseUrl, required requestHosts}) async {
        expect(requestHosts, ['api.source.example']);
        return '''
          <div class="book-result">
            <a class="title" href="/book/89">API Novel</a>
          </div>
        ''';
      },
    );
    final result = await repository.search('API');
    expect(result.items.single.title, 'API Novel');

    final blocked = BookSourceRepository(
      _config(searchUrlTemplate: 'https://api.source.example/search?q={keyword}&page={page}'),
      request: (url, {required baseUrl, required requestHosts}) async =>
          throw StateError('Unconfigured API hosts must be rejected before transport'),
    );
    await expectLater(blocked.search('API'), throwsFormatException);
  });

  test('blocks search result links that escape the configured origin', () async {
    final config = _config();
    final repository = BookSourceRepository(
      config,
      request: (url, {required baseUrl, required requestHosts}) async => '''
        <div class="book-result">
          <a class="title" href="https://outside.example/book">Outside</a>
        </div>
      ''',
    );
    final page = await repository.search('test');
    expect(page.items, isEmpty);
  });
}

BookSourceConfig _config({
  String baseUrl = 'https://source.example/',
  String searchUrlTemplate = '/search?q={keyword}&page={page}',
  String searchItemSelector = '.book-result',
  String searchTitleSelector = 'a.title',
  String chapterItemSelector = '#chapters a',
  String chapterContentSelector = '#content',
  String loginUrl = '',
  List<String> loginHosts = const [],
  List<String> requestHosts = const [],
  String browseUrlTemplate = '',
  List<String> imageHosts = const [],
  String searchAuthorSelector = '',
  String searchCoverSelector = '',
  String detailTitleSelector = '',
  String detailAuthorSelector = '',
  String detailSummarySelector = '',
  String detailGenreSelector = '',
  String detailStatusSelector = '',
  String detailCoverSelector = '',
}) => BookSourceConfig(
  id: 'test-source',
  name: 'Test source',
  baseUrl: baseUrl,
  loginUrl: loginUrl,
  loginHosts: loginHosts,
  requestHosts: requestHosts,
  browseUrlTemplate: browseUrlTemplate,
  searchUrlTemplate: searchUrlTemplate,
  searchItemSelector: searchItemSelector,
  searchTitleSelector: searchTitleSelector,
  chapterItemSelector: chapterItemSelector,
  chapterContentSelector: chapterContentSelector,
  imageHosts: imageHosts,
  searchAuthorSelector: searchAuthorSelector,
  searchCoverSelector: searchCoverSelector,
  detailTitleSelector: detailTitleSelector,
  detailAuthorSelector: detailAuthorSelector,
  detailSummarySelector: detailSummarySelector,
  detailGenreSelector: detailGenreSelector,
  detailStatusSelector: detailStatusSelector,
  detailCoverSelector: detailCoverSelector,
);
