import 'book_sources.dart';

/// Compatibility upgrades for built-in presets that changed domains or gained
/// a native reader adapter after they were first saved into user preferences.
///
/// Keep this outside BookSourceStore so older persisted JSON can be upgraded
/// without discarding the user's login cookies or source selection.
Future<void> upgradeBuiltInSourceCompatibility(BookSourceStore store) async {
  const linovelId = 'linovel-net-web';
  final linovelWasInstalled = store.byId(linovelId) != null;
  final linovelWasSelectedForLogin = store.loginSourceId == linovelId;
  final linovelWasLoggedIn = store.isSourceLoggedIn(linovelId);

  if (linovelWasInstalled) {
    await store.save(_linovelNetReader);
    if (linovelWasSelectedForLogin && linovelWasLoggedIn) {
      // v2283 treated this preset as web-login-only, so a successful login
      // silently fell back to Wenku8 for the Discover page. Once upgraded to a
      // real reader source, restore the user's intent and use it as homepage.
      await store.setHomepageSourceId(linovelId);
    }
  }

  const bilinovelId = 'linovelib-web';
  if (store.byId(bilinovelId) != null) {
    await store.save(_bilinovelLogin);
  }
}

/// Current linovel.net adapter.
///
/// Search/detail/catalog/chapter selectors are intentionally simple and match
/// the site's current public HTML. Browse uses the site's all-books category so
/// the Discover page never has to fall back to Wenku8 after a Linovel login.
const _linovelNetReader = BookSourceConfig(
  id: 'linovel-net-web',
  name: '轻之文库',
  baseUrl: 'https://www.linovel.net/',
  engine: 'css',
  enabled: true,
  loginUrl: '/auth/login',
  loginHosts: ['linovel.net'],
  requestHosts: ['linovel.net'],
  browseUrlTemplate: '/cat/-1.html?sort=hot&sign=-1&page={page}',
  searchUrlTemplate: '/search/?kw={keyword}&page={page}',
  // Search pages use .search-book; category pages use .book-draw.
  searchItemSelector: '.search-book, .book-draw',
  searchTitleSelector: '.book-name',
  searchAuthorSelector: '.book-extra',
  searchGenreSelector: '.book-tag',
  searchSummarySelector: '.book-intro',
  searchCoverSelector: '.book-cover img',
  searchCoverAttribute: 'src',
  detailTitleSelector: '.book-title',
  detailAuthorSelector: '.novelist > .name > a',
  detailSummarySelector: '.about-text',
  detailGenreSelector: '.book-cats',
  detailStatusSelector: '.book-data > span:nth-child(7)',
  detailCoverSelector: '.book-cover img',
  detailCoverAttribute: 'src',
  chapterItemSelector: '.section-list .chapter',
  chapterTitleSelector: 'a',
  chapterHrefSelector: 'a',
  chapterContentSelector: '.article-text > p',
  imageHosts: ['linovel.net'],
);

/// Bilinovel currently moves between the historical linovelib host and the
/// bilinovel .com/.net hosts. Keep this entry login-only for now, but allow its
/// known first-party HTTPS redirects so the embedded login page is usable.
const _bilinovelLogin = BookSourceConfig(
  id: 'linovelib-web',
  name: '哔哩轻小说',
  baseUrl: 'https://www.bilinovel.net/',
  engine: 'web_login_only',
  enabled: false,
  loginUrl: '/login.php',
  loginHosts: [
    'bilinovel.net',
    'www.bilinovel.com',
    'bilinovel.com',
    'www.linovelib.com',
    'linovelib.com',
  ],
  requestHosts: [
    'bilinovel.net',
    'www.bilinovel.com',
    'bilinovel.com',
    'www.linovelib.com',
    'linovelib.com',
  ],
  searchUrlTemplate: '',
  searchItemSelector: '',
  searchTitleSelector: '',
  chapterItemSelector: '',
  chapterContentSelector: '',
);
