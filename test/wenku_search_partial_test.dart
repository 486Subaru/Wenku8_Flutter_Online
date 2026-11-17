import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/legacy_wenku_repository.dart';
import 'package:wenku8_flutter/book_search.dart';
import 'package:wenku8_flutter/wenku8_html_parser.dart';

void main() {
  test('title results survive an independent author search failure', () async {
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        if (field == 'author') throw StateError('temporary author query failure');
        return '<a href="/book/123.htm">测试作品</a>';
      },
    );
    final found = await repository.searchFilteredPage('测试', field: BookSearchField.all);
    expect(found.items.single.id, 123);
    expect(found.searchFailures, contains(BookSearchField.author));
  });

  test('two failed fields are not reported as successful empty results', () async {
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async => '<title>Error 1015</title>',
    );
    final found = await repository.searchFilteredPage('测试', field: BookSearchField.all);
    expect(found.items, isEmpty);
    expect(found.searchFailures, contains(BookSearchField.title));
    expect(found.searchFailures, contains(BookSearchField.author));
  });

  test('pagination supports official page counter with no next-page anchors', () {
    const source = '<div id="content"><a href="/book/123.htm">测试作品</a></div>'
        '<div id="pagestats">1 / 6</div>';
    final found = Wenku8HtmlParser.parseSearchPage(source, 1);
    expect(found.totalPages, 6);
    expect(found.hasMore, isTrue);
  });
}
