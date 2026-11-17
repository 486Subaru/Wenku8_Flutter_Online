import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenku8_flutter/book_search.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/legacy_transport.dart';
import 'package:wenku8_flutter/legacy_wenku_repository.dart';
import 'package:wenku8_flutter/online_component.dart';
import 'package:wenku8_flutter/wenku_reviews.dart';

void emit(String name, Map<String, Object?> data) {
  debugPrint('WENKU_PROBE ${jsonEncode({'name': name, ...data})}', wrapWidth: 8192);
}

Map<String, Object?> classify(Object error) => {
  'type': error.runtimeType.toString(),
  if (error is PlatformException) 'code': error.code,
  if (error is OnlineRateLimited) 'retryAfterSeconds': error.retryAfterSeconds,
  if (error is FormatException) 'message': error.message,
  if (error is OnlineAccessRequired) 'message': error.message,
  if (error is OnlineRedirectBlocked) 'origin': error.origin,
};

Future<T?> runCase<T>(String name, Future<T> Function() run, Map<String, Object?> Function(T) summarize) async {
  final time = Stopwatch()..start();
  try {
    final result = await run();
    emit(name, {'ms': time.elapsedMilliseconds, ...summarize(result)});
    return result;
  } catch (error) {
    emit(name, {'ms': time.elapsedMilliseconds, 'status': 'error', ...classify(error)});
    return null;
  }
}

Map<String, Object?> pageSummary(NovelPage page) => {
  'status': page.searchFailures.isEmpty ? 'ok' : 'partial',
  'items': page.items.length,
  'hasMore': page.hasMore,
  'failures': page.searchFailures.map((field, error) => MapEntry(field.name, classify(error))),
};

Future<int> nativeChecks() async {
  final session = await runCase('fresh_session', LegacyTransport.hasSession, (value) => {'status': value ? 'unexpected' : 'ok', 'hasSession': value});
  var failures = session == false ? 0 : 1;
  for (final (name, method, args, code) in [
    ('bad_search', 'search', {'query': 'test', 'field': 'bogus'}, 'WEB_BAD_SEARCH'),
    ('offsite_url', 'getText', {'url': 'https://example.invalid/'}, 'WEB_BAD_URL'),
    ('bad_download', 'openPackDownload', {'bookId': 0, 'type': 'txt', 'node': 1}, 'WEB_BAD_DOWNLOAD'),
  ]) {
    try {
      await LegacyTransport.channel.invokeMethod<Object?>(method, args);
      failures++;
      emit(name, {'status': 'unexpected_success'});
    } on PlatformException catch (error) {
      if (error.code != code) failures++;
      emit(name, {'status': error.code == code ? 'ok' : 'unexpected', 'code': error.code});
    } catch (error) {
      failures++;
      emit(name, {'status': 'error', ...classify(error)});
    }
  }
  return failures;
}

Future<void> runProbe() async {
  final failures = await nativeChecks();
  final repo = LegacyWenkuRepository();
  final list = await runCase('discovery', () => repo.browse(), pageSummary);
  final timer = Stopwatch()..start();
  var showedFirst = false;
  final search = await runCase(
    'combined_search',
    () => repo.searchFilteredPage(
      '刀剑神域',
      field: BookSearchField.all,
      onProgress: (items) {
        if (showedFirst) return;
        showedFirst = true;
        emit('first_search_matches', {'ms': timer.elapsedMilliseconds, 'items': items.length});
      },
    ),
    pageSummary,
  );
  final candidates = search?.items.isNotEmpty == true ? search!.items : list?.items ?? const <Novel>[];
  if (candidates.isNotEmpty) {
    final book = await runCase('detail', () => repo.detail(candidates.first), (value) => {'status': 'ok', 'id': value.id});
    if (book != null) {
      final chapters = await runCase('contents', () => repo.chapters(book.id), (value) => {'status': 'ok', 'chapters': value.length});
      if (chapters != null) {
        for (final (index, chapter) in chapters.take(3).indexed) {
          final content = await runCase('chapter_${index + 1}', () => repo.chapterContent(book.id, chapter), (value) => {'status': value.isEmpty ? 'empty' : 'ok', 'length': value.length});
          if (content == null) break;
        }
      }
      await runCase('review_list', () => WenkuReviewFeed.readOfficial(book.id, 1, false), (value) => {'status': 'ok', 'items': value.items.length});
    }
  } else {
    emit('book_dependent_cases', {'status': 'skipped_no_book'});
  }
  emit('summary', {'nativeFailures': failures});
  emit('login_attempt', {'status': 'opening'});
  await runCase('login_return', LegacyTransport.openLogin, (value) => {'status': 'ok', 'loggedIn': value});
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Wenku8 emulator verification')))));
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(runProbe()));
}
