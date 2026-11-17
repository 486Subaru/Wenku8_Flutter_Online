import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/legacy_wenku_repository.dart';
import 'package:wenku8_flutter/book_search.dart';

void main() {
  test('title results remain visible after author search fails', () async {
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        if (field == 'author') throw StateError('author search temporarily blocked');
        return '<a href="/book/123.htm">测试作品</a>';
      },
    );
    final result = await repository.searchFilteredPage('测试', field: BookSearchField.all);
    expect(result.items.single.id, 123);
    expect(result.searchFailures, contains(BookSearchField.author));
  });

  test('Cloudflare 1015 page is a failure, never zero matching books', () async {
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async =>
          '<html><title>Error 1015</title>Cloudflare</html>',
    );
    final result = await repository.searchFilteredPage('测试', field: BookSearchField.all);
    expect(result.items, isEmpty);
    expect(result.searchFailures, contains(BookSearchField.title));
    expect(result.searchFailures, contains(BookSearchField.author));
  });
}
