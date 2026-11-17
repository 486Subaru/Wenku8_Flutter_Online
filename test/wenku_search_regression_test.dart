import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/legacy_transport.dart';
import 'package:wenku8_flutter/novel_feed_controller.dart';
import 'package:wenku8_flutter/online_component.dart';
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

  test('1015 stops the second official search and remains visible in the feed', () async {
    final requests = <String>[];
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        requests.add(field);
        return '<title>Error 1015</title><body>Cloudflare · 没有找到</body>';
      },
    );
    final feed = NovelFeedController(repository, search: true);
    addTearDown(feed.dispose);

    await feed.searchFor('测试');

    expect(requests, ['articlename']);
    expect(feed.incompleteSearchFields, {BookSearchField.title, BookSearchField.author});
    expect(feed.searchNotice, contains('1015'));
    expect(feed.items, isEmpty);
  });

  test('official transport preserves the limit code and remaining time', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      throw PlatformException(
        code: 'WEB_RATE_LIMITED',
        message: '官网限流，请稍后重试',
        details: {'retryAfterSeconds': 125},
      );
    });
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));

    await expectLater(
      LegacyTransport.search('测试'),
      throwsA(isA<OnlineRateLimited>().having((error) => error.retryAfterSeconds, 'seconds', 125)),
    );
  });

  test('ID search keeps transport failures visible', () async {
    final repository = LegacyWenkuRepository(
      request: (url, {referer}) async => throw const FormatException('连接失败'),
    );
    await expectLater(
      repository.searchFilteredPage('123', field: BookSearchField.id),
      throwsFormatException,
    );
  });

  test('an actual empty search is not marked as incomplete', () async {
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async =>
          '<body><div id="content">没有找到匹配的作品</div></body>',
    );
    final result = await repository.searchFilteredPage('测试');
    expect(result.items, isEmpty);
    expect(result.searchFailures, isEmpty);
  });
}
