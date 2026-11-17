import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/offline_cache.dart';
import 'package:wenku8_flutter/offline_repository.dart';
import 'package:wenku8_flutter/online_component.dart';

const _chapters = [
  NovelChapter('第一章', '', id: 101),
  NovelChapter('第二章', '', id: 102),
  NovelChapter('第三章', '', id: 103),
];

class _Remote extends DemoNovelRepository {
  int detailRequests = 0;
  int directoryRequests = 0;
  final chapterRequests = <int>[];
  int? limitedChapter;
  bool limitedDirectory = false;
  final clock = Stopwatch()..start();
  final starts = <Duration>[];

  OnlineRateLimited get _limit =>
      OnlineRateLimited('官网 Cloudflare 1015 限流', retryAfterSeconds: 780);

  @override
  Future<Novel> detail(Novel novel) async {
    starts.add(clock.elapsed);
    detailRequests++;
    return novel;
  }

  @override
  Future<List<NovelChapter>> chapters(int id) async {
    starts.add(clock.elapsed);
    directoryRequests++;
    if (limitedDirectory) throw _limit;
    return _chapters;
  }

  @override
  Future<String> chapterContent(int id, NovelChapter chapter) async {
    starts.add(clock.elapsed);
    chapterRequests.add(chapter.id);
    if (limitedChapter == chapter.id) throw _limit;
    return '正文 ${chapter.id}';
  }
}

Future<ChapterDownload> _finished(OfflineNovelRepository repository, int id) async {
  final deadline = Stopwatch()..start();
  while (deadline.elapsed < const Duration(seconds: 3)) {
    final job = repository.jobFor(id);
    if (job != null && !job.active) return job;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('批量缓存未结束');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final book = demoNovels.first.withChapters(const []);
  late Directory directory;
  late OfflineCacheStore cache;
  late OfflineNovelRepository repository;
  late _Remote remote;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wenku-cache-resume-');
    cache = OfflineCacheStore(directory);
    remote = _Remote();
    repository = OfflineNovelRepository(
      remote: remote,
      cache: cache,
      officialCacheInterval: Duration.zero,
    );
  });

  tearDown(() async {
    repository.dispose();
    cache.dispose();
    await directory.delete(recursive: true);
  });

  test('1015 后从缺失章节继续且不重新请求目录', () async {
    remote.limitedChapter = 102;
    repository.download(book);
    final failed = await _finished(repository, book.id);
    expect(failed.phase, DownloadPhase.failed);
    expect(failed.label, contains('1015'));
    expect(failed.label, isNot(contains('获取目录失败')));
    expect(await cache.readChapter(book.id, 101), '正文 101');
    expect(await cache.readChapter(book.id, 102), isNull);

    remote.limitedChapter = null;
    repository.retry(book.id);
    final resumed = await _finished(repository, book.id);
    expect(resumed.phase, DownloadPhase.completed);
    expect(resumed.completed, 3);
    expect(remote.detailRequests, 1);
    expect(remote.directoryRequests, 1);
    expect(remote.chapterRequests, [101, 102, 102, 103]);
    expect(await cache.readChapter(book.id, 103), '正文 103');
  });

  test('选章缓存复用已加载目录', () async {
    remote.limitedDirectory = true;
    repository.download(book.withChapters(_chapters), chapterIds: {102});
    expect((await _finished(repository, book.id)).phase, DownloadPhase.completed);
    expect(remote.detailRequests, 0);
    expect(remote.directoryRequests, 0);
    expect(remote.chapterRequests, [102]);
  });

  test('拉目录被限流时显示 1015 而非笼统的目录失败', () async {
    remote.limitedDirectory = true;
    repository.download(book);
    final failed = await _finished(repository, book.id);
    expect(failed.phase, DownloadPhase.failed);
    expect(failed.label, contains('1015'));
    expect(failed.label, isNot(contains('获取目录失败')));
    expect(remote.chapterRequests, isEmpty);
  });

  test('官网批量缓存只给实际请求留出间隔', () async {
    const interval = Duration(milliseconds: 25);
    repository.dispose();
    repository = OfflineNovelRepository(
      remote: remote,
      cache: cache,
      officialCacheInterval: interval,
    );
    repository.download(book);
    expect((await _finished(repository, book.id)).phase, DownloadPhase.completed);
    expect(remote.starts.length, 5);
    for (var index = 1; index < remote.starts.length; index++) {
      expect(
        remote.starts[index] - remote.starts[index - 1],
        greaterThanOrEqualTo(interval - const Duration(milliseconds: 2)),
      );
    }
  });

  test('清理缓存后重试会重新获取目录', () async {
    remote.limitedChapter = 102;
    repository.download(book);
    final failed = await _finished(repository, book.id);
    expect(failed.phase, DownloadPhase.failed);
    await cache.removeBook(book.id);

    remote.limitedChapter = null;
    repository.retry(book.id);
    expect((await _finished(repository, book.id)).phase, DownloadPhase.completed);
    expect(remote.directoryRequests, 2);
    expect(remote.chapterRequests, [101, 102, 101, 102, 103]);
  });
}
