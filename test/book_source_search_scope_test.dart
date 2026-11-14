import 'package:flutter_test/flutter_test.dart';
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
