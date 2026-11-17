import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/offline_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('损坏的插图缓存会被识别并可重新写入', () async {
    final directory = await Directory.systemTemp.createTemp('wenku-image-');
    final cache = OfflineCacheStore(directory);
    addTearDown(() async {
      cache.dispose();
      await directory.delete(recursive: true);
    });
    final book = demoNovels.first.withChapters(const [
      NovelChapter('插图', '', id: 101),
    ]);
    final epoch = cache.epochFor(book.id);
    const url = 'https://img.wenku8.com/image/4/4265/illust.jpg';
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
    );
    final invalid = Uint8List.fromList(utf8.encode('<html>403 Forbidden</html>'));
    expect(await cache.saveBook(book, epoch: epoch), isTrue);

    await expectLater(
      cache.saveIllustration(book.id, url, invalid, epoch: epoch),
      throwsFormatException,
    );
    expect(await cache.hasIllustration(book.id, url), isFalse);
    expect(await cache.saveIllustration(book.id, url, png, epoch: epoch), isTrue);

    final saved = await directory
        .list(recursive: true)
        .where((entry) => entry.path.endsWith('.image'))
        .cast<File>()
        .single;
    await saved.writeAsBytes(Uint8List(png.length));
    expect(await cache.hasIllustration(book.id, url), isFalse);
    expect(await cache.readIllustration(url), isNull);
    expect(await cache.saveIllustration(book.id, url, png, epoch: epoch), isTrue);
    expect(await cache.readIllustration(url), orderedEquals(png));
  });
}
