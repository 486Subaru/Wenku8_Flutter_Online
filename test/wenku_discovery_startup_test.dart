import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/offline_cache.dart';
import 'package:wenku8_flutter/offline_repository.dart';
import 'package:wenku8_flutter/online_component.dart';
import 'package:wenku8_flutter/pages.dart';

class _CountingRepository extends DemoNovelRepository {
  int requests = 0;

  @override
  Future<NovelPage> browse({
    NovelSort sort = NovelSort.lastUpdate,
    int page = 1,
    bool refresh = false,
  }) async {
    requests++;
    throw OnlineRateLimited('官网 Cloudflare 1015 限流', retryAfterSeconds: 900);
  }
}

void main() {
  testWidgets('发现冷启动无请求，点击加载后只发一次且不自动重试',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final state = LibraryState(preferences);
    final cache = (await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('wenku-cold-start-');
      final result = OfflineCacheStore(directory);
      await result.load();
      return result;
    }))!;
    final remote = _CountingRepository();
    final repository = OfflineNovelRepository(remote: remote, cache: cache);

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(state: state, repository: repository),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(remote.requests, 0);

    await tester.tap(find.byKey(const ValueKey('discover-load-official')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(remote.requests, 1);
    expect(find.textContaining('1015'), findsOneWidget);

    await tester.tap(find.text('书架').last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('发现').last);
    await tester.pump(const Duration(milliseconds: 350));
    expect(remote.requests, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
    cache.dispose();
    state.dispose();
    await tester.runAsync(() => cache.directory.delete(recursive: true));
  });
}
