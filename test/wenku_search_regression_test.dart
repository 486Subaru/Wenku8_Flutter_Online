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

  for (final accessError in <OnlineAccessRequired>[
    const OnlineChallengeRequired(),
    const OnlineAuthenticationRequired(),
    const OnlineRedirectBlocked(origin: 'https://example.com'),
  ]) {
    test('${accessError.runtimeType} skips author and explains empty search', () async {
      final requests = <String>[];
      final repository = LegacyWenkuRepository(
        searchRequest: (query, {field = 'articlename', page = 1}) async {
          requests.add(field);
          throw accessError;
        },
      );
      final feed = NovelFeedController(repository, search: true);
      addTearDown(feed.dispose);

      await feed.searchFor('测试');

      expect(requests, ['articlename']);
      expect(feed.items, isEmpty);
      expect(feed.searchAccessRequired, same(accessError));
      expect(feed.searchNotice, contains(accessError.message));
    });
  }

  test('a blocked author search preserves title results and access guidance', () async {
    const accessError = OnlineChallengeRequired();
    final repository = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        if (field == 'author') throw accessError;
        return '<a href="/book/123.htm">测试作品</a>';
      },
    );
    final feed = NovelFeedController(repository, search: true);
    addTearDown(feed.dispose);

    await feed.searchFor('测试');

    expect(feed.items.single.id, 123);
    expect(feed.incompleteSearchFields, {BookSearchField.author});
    expect(feed.searchAccessRequired, same(accessError));
  });

  test('official transport distinguishes interactive verification and unsafe redirect', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));

    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      throw PlatformException(code: 'WEB_VERIFICATION_REQUIRED');
    });
    await expectLater(LegacyTransport.search('测试'), throwsA(isA<OnlineChallengeRequired>()));

    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      throw PlatformException(
        code: 'WEB_REDIRECT_BLOCKED',
        details: {'origin': 'https://example.com'},
      );
    });
    await expectLater(
      LegacyTransport.search('测试'),
      throwsA(isA<OnlineRedirectBlocked>().having((error) => error.origin, 'origin', 'https://example.com')),
    );
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

  test('accepts the official empty grid without using unrelated book links', () async {
    final repo = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async => '''
        <title>WenkuProbeQQ4927搜索结果 - 轻小说文库</title>
        <aside><a href="/book/999.htm">无关推荐</a></aside>
        <div id="content">
          <table class="grid"><caption>“WenkuProbeQQ4927”搜索结果</caption></table>
          <div class="pages"><span id="pagestats">1/1</span></div>
        </div>
      ''',
    );
    final result = await repo.searchFilteredPage('WenkuProbeQQ4927', field: BookSearchField.title);
    expect(result.items, isEmpty);
    expect(result.searchFailures, isEmpty);
    expect(result.hasMore, isFalse);
  });

  test('an error containing a generic missing message is not a zero-result search', () async {
    final repo = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async =>
          '<title>请求失败</title><div id="content">没有找到登录会话</div>',
    );
    final result = await repo.searchFilteredPage('魔法', field: BookSearchField.title);
    expect(result.items, isEmpty);
    expect(result.searchFailures[BookSearchField.title], isA<FormatException>());
  });

  test('reads official results inside the grid and preserves the reported last page', () async {
    final repo = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async => '''
        <title>魔法搜索结果 - 轻小说文库</title>
        <aside><a href="/book/999.htm">无关推荐</a></aside>
        <div id="content">
          <table class="grid"><tr><td><a href="/book/4358.htm">测试作品</a></td></tr></table>
          <div class="pages"><span id="pagestats">1/7</span></div>
        </div>
      ''',
    );
    final result = await repo.searchFilteredPage('魔法', field: BookSearchField.title);
    expect(result.items.map((book) => book.id), [4358]);
    expect(result.totalPages, 7);
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
