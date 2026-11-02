import 'package:flutter_test/flutter_test.dart';

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

    test('round trips its JSON configuration', () {
      final config = _config(
        loginUrl: '/login',
        imageHosts: const ['cdn.source.example'],
      );
      final restored = BookSourceConfig.fromJson(Map<String, dynamic>.from(config.toJson()));
      restored.validate();
      expect(restored.id, config.id);
      expect(restored.loginUrl, '/login');
      expect(restored.imageHosts, ['cdn.source.example']);
    });
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
      request: (url, {required baseUrl}) async {
        expect(baseUrl, config.baseUrl);
        requests.add(url);
        final response = responses[url];
        if (response == null) throw StateError('Unexpected URL: ' + url);
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

  test('blocks search result links that escape the configured origin', () async {
    final config = _config();
    final repository = BookSourceRepository(
      config,
      request: (url, {required baseUrl}) async => '''
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
