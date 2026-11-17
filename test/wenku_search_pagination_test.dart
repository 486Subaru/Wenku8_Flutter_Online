import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/book_search.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/legacy_wenku_repository.dart';
import 'package:wenku8_flutter/novel_feed_controller.dart';
import 'package:wenku8_flutter/online_component.dart';

String bookPage(int start, int count, int page, int pages) {
  final rows = [
    for (var id = start; id < start + count; id++)
      '<div><a href="/book/$id.htm"><img alt=""></a>'
          '<a href="/book/$id.htm">测试作品 $id</a></div>',
  ].join();
  return '<div id="content">$rows</div><div id="pagestats">$page/$pages</div>';
}

const emptyPage = '<div id="content">没有找到匹配的作品</div>';

void main() {
  test('separate title and author modes retain the observed official page sizes', () async {
    final queries = <String>[];
    final repo = LegacyWenkuRepository(
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        queries.add('$query:$field:$page');
        return switch ((query, field, page)) {
          ('魔法', 'articlename', 1) => bookPage(100, 20, 1, 7),
          ('魔法', 'articlename', 2) => bookPage(120, 20, 2, 7),
          ('伏见司', 'author', 1) => bookPage(200, 5, 1, 1),
          _ => throw StateError('Unexpected fixture request'),
        };
      },
    );
    final feed = NovelFeedController(repo, search: true);
    addTearDown(feed.dispose);

    await feed.selectSearchField(BookSearchField.title);
    await feed.searchFor('魔法');
    expect(feed.items, hasLength(20));
    expect(feed.hasMore, isTrue);
    await feed.loadMore();
    expect(feed.items.map((book) => book.id), List.generate(40, (i) => 100 + i));
    expect(feed.page, 2);
    expect(feed.hasMore, isTrue);

    await feed.searchFor('');
    await feed.selectSearchField(BookSearchField.author);
    await feed.searchFor('伏见司');
    expect(feed.items, hasLength(5));
    expect(feed.hasMore, isFalse);
    expect(queries, ['魔法:articlename:1', '魔法:articlename:2', '伏见司:author:1']);
  });

  test('combined search shows title first, and skips an exhausted author field on page two', () async {
    final queries = <String>[];
    final author = Completer<String>();
    final repo = LegacyWenkuRepository(
      searchRequest: (_, {field = 'articlename', page = 1}) async {
        queries.add('$field:$page');
        if (field == 'author') return page == 1 ? author.future : emptyPage;
        return bookPage(100 + (page - 1) * 20, 20, page, 7);
      },
    );
    final feed = NovelFeedController(repo, search: true);
    addTearDown(feed.dispose);
    final titleVisible = Completer<void>();
    feed.addListener(() {
      if (feed.items.length == 20 && !titleVisible.isCompleted) titleVisible.complete();
    });

    final firstPage = feed.searchFor('回放关键词');
    await titleVisible.future.timeout(const Duration(seconds: 3));
    expect(feed.loading, isTrue);
    author.complete(bookPage(200, 5, 1, 1));
    await firstPage;
    expect(feed.items, hasLength(25));
    await feed.loadMore();
    expect(feed.items, hasLength(45));
    expect(feed.hasMore, isTrue);
    expect(queries, ['articlename:1', 'author:1', 'articlename:2']);
  });

  test('a rate-limited later page retains old books but retry resumes it without replaying successful pages', () async {
    final queries = <String>[];
    var failNextPage = true;
    final repo = LegacyWenkuRepository(
      searchRequest: (_, {field = 'articlename', page = 1}) async {
        queries.add('$field:$page');
        if (field == 'author') return emptyPage;
        if (page == 2 && failNextPage) throw OnlineRateLimited('官网 Cloudflare 1015 限流');
        return bookPage(100 + (page - 1) * 20, 20, page, 7);
      },
    );
    final feed = NovelFeedController(repo, search: true);
    addTearDown(feed.dispose);

    await feed.searchFor('回放关键词');
    await feed.loadMore();
    expect(feed.items, hasLength(20));
    expect(feed.searchNotice, contains('1015'));
    expect(feed.hasMore, isFalse);
    expect(queries, ['articlename:1', 'author:1', 'articlename:2']);

    failNextPage = false;
    await feed.retry();
    expect(feed.items, hasLength(40));
    expect(feed.searchNotice, isNull);
    expect(queries.skip(3), ['articlename:2']);
  });
  test('retry only fetches the failed field on a partial successful page', () async {
    final queries = <String>[];
    var authorFails = true;
    final repo = LegacyWenkuRepository(
      searchRequest: (_, {field = 'articlename', page = 1}) async {
        queries.add('$field:$page');
        if (field == 'author' && authorFails) throw StateError('temporarily unavailable');
        return field == 'author'
            ? bookPage(200, 5, page, 1)
            : bookPage(100, 20, page, 3);
      },
    );
    final feed = NovelFeedController(repo, search: true);
    addTearDown(feed.dispose);

    await feed.searchFor('回放关键词');
    expect(feed.items, hasLength(20));
    expect(feed.incompleteSearchFields, {BookSearchField.author});

    authorFails = false;
    await feed.retry();
    expect(queries, ['articlename:1', 'author:1', 'author:1']);
    expect(feed.items, hasLength(25));
    expect(feed.page, 1);
    expect(feed.hasMore, isTrue);
    expect(feed.searchNotice, isNull);
  });

  test('missing title page metadata never borrows the completed author cursor', () async {
    final queries = <String>[];
    final repo = LegacyWenkuRepository(
      searchRequest: (_, {field = 'articlename', page = 1}) async {
        queries.add('$field:$page');
        if (field == 'author') return emptyPage;
        return '<div id="content"><a href="/book/$page.htm">第 $page 页</a></div>';
      },
    );
    final feed = NovelFeedController(repo, search: true);
    addTearDown(feed.dispose);

    await feed.searchFor('回放关键词');
    expect(feed.hasMore, isTrue);
    await feed.loadMore();
    expect(feed.items.map((book) => book.id), [1, 2]);
    expect(queries, ['articlename:1', 'author:1', 'articlename:2']);
  });

  test('an incomplete full refresh retains both visible pages until recovery', () async {
    final queries = <String>[];
    var refreshing = false;
    var fail = false;
    final repo = LegacyWenkuRepository(
      searchRequest: (_, {field = 'articlename', page = 1}) async {
        queries.add('$field:$page');
        if (field == 'author') return emptyPage;
        if (page == 2 && fail) throw OnlineRateLimited('官网 Cloudflare 1015 限流');
        return bookPage((refreshing ? 300 : 100) + (page - 1) * 20, 20, page, 7);
      },
    );
    final feed = NovelFeedController(repo, search: true);
    addTearDown(feed.dispose);
    await feed.searchFor('回放关键词');
    await feed.loadMore();

    refreshing = true;
    fail = true;
    await feed.refresh();
    expect(feed.items.map((book) => book.id), List.generate(40, (i) => 100 + i));
    expect(feed.page, 2);
    expect(feed.searchNotice, contains('1015'));

    queries.clear();
    fail = false;
    await feed.retry();
    expect(queries, ['articlename:2']);
    expect(feed.items.map((book) => book.id), List.generate(40, (i) => 300 + i));
    expect(feed.page, 2);
    expect(feed.searchNotice, isNull);
  });

  test('a repeated first page cannot silently consume the second page cursor', () async {
    final queries = <String>[];
    var repeatFirst = true;
    final repo = LegacyWenkuRepository(
      searchRequest: (_, {field = 'articlename', page = 1}) async {
        queries.add('$field:$page');
        if (field == 'author') return emptyPage;
        if (page == 1 || repeatFirst) return bookPage(100, 20, 1, 7);
        return bookPage(120, 20, 2, 7);
      },
    );
    final feed = NovelFeedController(repo, search: true);
    addTearDown(feed.dispose);
    await feed.searchFor('回放关键词');
    await feed.loadMore();
    expect(feed.items, hasLength(20));
    expect(feed.searchNotice, isNotNull);

    repeatFirst = false;
    await feed.retry();
    expect(queries, ['articlename:1', 'author:1', 'articlename:2', 'articlename:2']);
    expect(feed.items, hasLength(40));
    expect(feed.searchNotice, isNull);
  });

  test('opening search can defer follow-up discovery requests already in progress', () async {
    final repository = ReplayDiscoveryRepository();
    final feed = NovelFeedController(repository, initialItems: 2);
    addTearDown(feed.dispose);
    final load = feed.loadInitial();
    feed.deferBackgroundPaging(true);
    repository.first.complete(NovelPage(items: [demoNovels.first], page: 1, totalPages: 2));
    await load;
    expect(repository.requests, [1]);
    expect(feed.items, hasLength(1));
    expect(feed.deferBackgroundPaging(false), isTrue);
    await feed.loadMore();
    expect(repository.requests, [1, 2]);
    expect(feed.items, hasLength(2));
  });

}

class ReplayDiscoveryRepository extends DemoNovelRepository {
  final first = Completer<NovelPage>();
  final requests = <int>[];

  @override
  Future<NovelPage> browse({
    NovelSort sort = NovelSort.lastUpdate,
    int page = 1,
    bool refresh = false,
  }) async {
    requests.add(page);
    if (page == 1) return first.future;
    return NovelPage(items: [demoNovels[1]], page: page, totalPages: 2);
  }
}
