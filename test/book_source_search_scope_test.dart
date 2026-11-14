import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:wenku8_flutter/legacy_transport.dart';
import 'package:wenku8_flutter/built_in_source_upgrades.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/book_sources.dart';
import 'package:wenku8_flutter/book_search.dart';
import 'package:wenku8_flutter/legacy_wenku_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('search participation is independent of homepage selection and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);
    await store.load();
    expect(store.searchSourceCount, 1);
    await store.installPreset('lightnovel-fun');
    await store.installPreset('linovel-net-web');
    await store.setHomepageSourceId('lightnovel-fun');
    await store.setEnabled('lightnovel-fun', false);
    await store.setOfficialSearchEnabled(false);
    expect(store.homepageSourceId, 'lightnovel-fun');
    expect(store.enabledSources.map((source) => source.id), ['linovel-net-web']);
    expect(store.searchSourceCount, 1);
    final reopened = BookSourceStore(preferences);
    await reopened.load();
    expect(reopened.officialSearchEnabled, false);
    expect(reopened.searchSourceCount, 1);
    expect(reopened.homepageSourceId, 'lightnovel-fun');
  });

  test('search calls every enabled source, not the disabled homepage, and retains results during an outage', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BookSourceStore(await SharedPreferences.getInstance());
    await store.load();
    BookSourceConfig source(String id, {bool enabled = true}) => BookSourceConfig(
      id: id, name: id, baseUrl: 'https://$id.example/',
      enabled: enabled, searchUrlTemplate: '/search?q={keyword}&page={page}',
      searchItemSelector: '.book', searchTitleSelector: 'a',
      chapterItemSelector: '#chapters a', chapterContentSelector: '#content',
    );
    await store.save(source('first'));
    await store.save(source('second'));
    await store.save(source('homepage', enabled: false));
    await store.setHomepageSourceId('homepage');
    var officialCalls = 0;
    var officialFails = false;
    var secondFails = false;
    final seen = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      expect(call.method, 'getSourceText');
      final args = call.arguments as Map;
      final host = Uri.parse(args['url'] as String).host;
      seen.add(host);
      if (host == 'second.example' && secondFails) {
        throw PlatformException(code: 'SOURCE_CHALLENGE', message: 'test outage');
      }
      return '<div class="book"><a href="/book/1">测试 $host</a></div>';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));
    final repository = LegacyWenkuRepository(
      bookSources: store,
      searchRequest: (query, {field = 'articlename', page = 1}) async {
        officialCalls++;
        if (officialFails) throw StateError('official outage');
        return '<div id="content"><a href="/book/42.htm">测试 文库</a></div>';
      },
    );
    final first = await repository.searchFilteredPage('测试', field: BookSearchField.title);
    expect(first.items.map((item) => item.sourceId).toSet(), {null, 'first', 'second'});
    expect(seen.toSet(), {'first.example', 'second.example'});
    expect(officialCalls, 1);
    officialFails = true;
    secondFails = true;
    seen.clear();
    final partial = await repository.searchFilteredPage('测试', field: BookSearchField.title);
    expect(partial.items.single.sourceId, 'first');
    expect(partial.searchFailures, contains(BookSearchField.title));
    expect(seen.toSet(), {'first.example', 'second.example'});
    await store.setOfficialSearchEnabled(false);
    await store.setEnabled('second', false);
    seen.clear();
    final calls = officialCalls;
    final selected = await repository.searchFilteredPage('测试', field: BookSearchField.title);
    expect(selected.items.single.sourceId, 'first');
    expect(selected.searchFailures, isEmpty);
    expect(seen, ['first.example']);
    expect(officialCalls, calls);
    expect(store.homepageSourceId, 'homepage');
  });

  test('compatibility upgrade preserves explicitly disabled built-in reader', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = BookSourceStore(preferences);
    await store.load();
    await store.installPreset('linovel-net-web');
    await store.setEnabled('linovel-net-web', false);
    await upgradeBuiltInSourceCompatibility(store);
    final reopened = BookSourceStore(preferences);
    await reopened.load();
    expect(reopened.byId('linovel-net-web')!.enabled, false);
    expect(reopened.enabledSources, isEmpty);
  });

  test('no selected search sources gives an actionable error', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BookSourceStore(await SharedPreferences.getInstance());
    await store.load();
    await store.setOfficialSearchEnabled(false);
    final repository = LegacyWenkuRepository(bookSources: store);
    await expectLater(
      repository.searchFilteredPage('测试', field: BookSearchField.title),
      throwsFormatException,
    );
  });
}
