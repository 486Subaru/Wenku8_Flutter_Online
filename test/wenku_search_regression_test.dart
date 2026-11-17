import 'dart:async';

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

  test('ID search treats an official 404 as a genuine missing book', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      throw PlatformException(code: 'WEB_NOT_FOUND');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));

    final result = await LegacyWenkuRepository().searchFilteredPage(
      '123',
      field: BookSearchField.id,
    );
    expect(result.items, isEmpty);
    expect(result.searchFailures, isEmpty);
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

  test('shows title matches while the author search is still pending', () async {
    final authorReply = Completer<String>();
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        if (field == 'author') return authorReply.future;
        return '<a href="/book/123.htm">书名匹配</a>';
      },
    );
    final feed = NovelFeedController(repository, search: true);
    addTearDown(feed.dispose);
    final visible = Completer<void>();
    feed.addListener(() {
      if (feed.items.isNotEmpty && !visible.isCompleted) visible.complete();
    });

    final finished = feed.searchFor('测试');
    await visible.future.timeout(const Duration(seconds: 2));
    expect(feed.items.single.id, 123);
    expect(feed.loading, isTrue);

    authorReply.complete('<a href="/book/456.htm">作者匹配</a>');
    await finished;
    expect(feed.items.map((book) => book.id), [123, 456]);
    expect(feed.loading, isFalse);
  });

  test('closing search while title is in flight skips the stale author request', () async {
    final titleReply = Completer<String>();
    final requests = <String>[];
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        requests.add(field);
        return titleReply.future;
      },
    );
    final feed = NovelFeedController(repository, search: true);
    addTearDown(feed.dispose);
    final finished = feed.searchFor('测试');
    expect(requests, ['articlename']);
    feed.cancelScheduledSearch();
    titleReply.complete('<a href="/book/123.htm">旧搜索</a>');
    await finished;
    expect(requests, ['articlename']);
    expect(feed.items, isEmpty);
  });
}
