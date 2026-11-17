import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'wenku_reviews.dart';

import 'legacy_transport.dart';
import 'library_state.dart';
import 'online_component.dart';
import 'wenku_shelf_sync.dart' show CloudShelfPlan;
import 'wenku8_html_parser.dart';

class WenkuProfile {
  const WenkuProfile({
    required this.id,
    required this.username,
    required this.nickname,
    required this.score,
    required this.experience,
    required this.rank,
  });
  final int id, score, experience;
  final String username, nickname, rank;
  String get displayName => nickname.isEmpty ? username : nickname;
}

class CloudBook {
  const CloudBook({
    required this.id,
    this.title = '',
    this.updated = '',
    this.latestChapterId = 0,
    this.latestChapter = '',
  });
  final int id, latestChapterId;
  final String title, updated, latestChapter;
}

class CloudUploadResult {
  const CloudUploadResult(this.uploaded, this.remaining, this.error);
  final List<int> uploaded, remaining;
  final Object? error;
}

/// Account state for the official-site WebView session. Passwords are entered
/// on Wenku8's own page and are never passed through this class or a relay.
class WenkuAccount extends ChangeNotifier {
  WenkuAccount();

  Uint8List? avatar;
  bool authenticated = false, busy = false, signedToday = false;
  String? operation, error;
  WenkuProfile? profile;
  List<CloudBook>? cloudBooks;
  int? syncedAt;
  int _sessionRevision = 0;
  int _publicationRevision = 0;

  int get sessionRevision => _sessionRevision;
  int get publicationRevision => _publicationRevision;

  static String describeError(Object error) =>
      error is OnlineComponentUnavailable ||
          error is OnlineAuthenticationRequired ||
          error is OnlineChallengeRequired
      ? error.toString()
      : error is FormatException
      ? error.message.toString()
      : '网络或本地存储暂时异常，请重试';

  Future<void> initialize() async {
    if (busy) return;
    try {
      final current = await LegacyTransport.hasSession();
      if (current != authenticated) {
        authenticated = current;
        _sessionRevision++;
        _publicationRevision++;
        if (!current) {
          profile = null;
          avatar = null;
          cloudBooks = null;
          signedToday = false;
          syncedAt = null;
        }
      }
      error = null;
    } catch (failure) {
      error = describeError(failure);
    }
    notifyListeners();
  }

  /// The arguments are retained for compatibility with the existing UI API.
  /// Authentication itself takes place in the official-site WebView.
  Future<void> login(String _username, String _password) async {
    if (busy) return;
    busy = true;
    operation = '正在打开文库官网';
    error = null;
    notifyListeners();
    try {
      final accepted = await LegacyTransport.openLogin();
      if (!accepted || !await LegacyTransport.hasSession()) {
        throw const FormatException('尚未完成文库官网登录');
      }
      authenticated = true;
      profile = null;
      avatar = null;
      cloudBooks = null;
      signedToday = false;
      _sessionRevision++;
      _publicationRevision++;
    } catch (failure) {
      error = describeError(failure);
      rethrow;
    } finally {
      busy = false;
      operation = null;
      notifyListeners();
    }
  }

  /// Check the same official endpoint as the recent-updates discovery page.
  /// Preserve a valid account session if the site rejects the list request.
  Future<void> verifyDiscoveryAccess() async {
    if (busy) return;
    busy = true;
    operation = '正在检查官网书籍列表';
    error = null;
    notifyListeners();
    try {
      final html = await LegacyTransport.getText(
        '${Wenku8HtmlParser.base}modules/article/toplist.php?sort=lastupdate&page=1',
        referer: '${Wenku8HtmlParser.base}index.php',
      );
      if (Wenku8HtmlParser.parseBookList(html).isEmpty) {
        throw const FormatException('已登录，但官网未返回可识别的书籍列表；请重试');
      }
    } catch (failure) {
      error = '已保存网页登录状态，但发现页尚未连接：${describeError(failure)}';
      rethrow;
    } finally {
      busy = false;
      operation = null;
      notifyListeners();
    }
  }

  Future<void> connectPublications(String _password) => login('', '');

  static WenkuProfile parseOfficialProfile(String source) {
    final fields = <String, String>{};
    for (final row in html.parse(source).querySelectorAll('tr')) {
      final cells = row.children.where((cell) => cell.localName == 'td').toList();
      if (cells.length < 2) continue;
      final key = cells.first.text.replaceAll(RegExp(r'[\s：:]'), '');
      for (final cell in cells.skip(1)) {
        final text = (cell.querySelector('input[value]')?.attributes['value'] ?? cell.text).trim();
        if (text.isNotEmpty) {
          fields.putIfAbsent(key, () => text);
          break;
        }
      }
    }
    String field(List<String> names) {
      for (final name in names) {
        if ((fields[name] ?? '').isNotEmpty) return fields[name]!;
      }
      return '';
    }
    int number(List<String> names) =>
        int.tryParse(field(names).replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final id = number(['用户ID', 'UID', '用户编号']);
    final username = field(['用户名', '用户名称']);
    if (id <= 0 && username.isEmpty) {
      throw const FormatException('官网未返回账号资料，请检查登录状态');
    }
    return WenkuProfile(
      id: id, username: username, nickname: field(['昵称']),
      score: number(['现有积分', '积分']),
      experience: number(['经验值', '经验']),
      rank: field(['等级', '头衔']),
    );
  }

  Future<T> _accountAction<T>(String title, Future<T> Function() action) async {
    if (busy) throw const FormatException('账号操作正在进行，请稍后重试');
    if (!authenticated) await initialize();
    if (!authenticated || !await LegacyTransport.hasSession()) {
      throw const OnlineAuthenticationRequired();
    }
    busy = true;
    operation = title;
    error = null;
    notifyListeners();
    try {
      return await action();
    } catch (failure) {
      error = describeError(failure);
      rethrow;
    } finally {
      busy = false;
      operation = null;
      notifyListeners();
    }
  }

  Future<WenkuProfile> _readProfile() async =>
      parseOfficialProfile(await LegacyTransport.getText(
        '${Wenku8HtmlParser.base}userdetail.php',
      ));

  Future<void> refreshProfile() => _accountAction('正在读取账号资料', () async {
    profile = await _readProfile();
  });


  Future<T> _notRestored<T>(String feature) async {
    final message = '$feature功能正在恢复，当前版本暂未开放';
    error = message;
    notifyListeners();
    throw FormatException(message);
  }

  Future<void> signIn() => _notRestored('每日签到');
  Future<List<CloudBook>> refreshCloud() => _notRestored('云书架');
  Future<CloudShelfPlan> exchangeShelf({
    required Set<int> local,
    Set<int>? lastLocal,
    Set<int>? lastCloud,
  }) => _notRestored('云书架同步');
  Future<CloudUploadResult> uploadMissing(Set<int> localIds) =>
      _notRestored('云书架上传');
  Future<void> addCloud(int id) => _notRestored('云端收藏');
  Future<void> removeCloud(int id) => _notRestored('云端收藏');
  Future<void> recommend(int id) => _notRestored('作品推荐');
  static bool _isAuthor(WenkuReview item, WenkuProfile author) =>
      author.id > 0 && item.userId == author.id ||
      author.username.isNotEmpty && item.user == author.username ||
      author.nickname.isNotEmpty && item.user == author.nickname;

  Future<void> postReview({
    required int bookId,
    required String title,
    required String content,
  }) => _accountAction('正在发表书评', () async {
    if (bookId <= 0 || bookId >= 0x40000000 ||
        title.trim().isEmpty || content.trim().length < 10) {
      throw const FormatException('作品编号或书评内容无效');
    }
    final author = profile ??= await _readProfile();
    final before = await WenkuReviewFeed.readOfficial(bookId, 1, false);
    final previousIds = before.items.map((item) => item.id).toSet();
    // Wenku8 web form accepts only pcontent. The title is carried in the body.
    final body = '${title.trim()}\n${content.trim()}';
    await LegacyTransport.officialAction(
      '${Wenku8HtmlParser.base}modules/article/reviews.php?aid=$bookId',
      content: body,
    );
    // Never retry a non-idempotent POST. Only confirm by reading the site again.
    final after = await WenkuReviewFeed.readOfficial(bookId, 1, false);
    final newItems = after.items.where((item) =>
        !previousIds.contains(item.id) && _isAuthor(item, author));
    for (final item in newItems) {
      final thread = await WenkuReviewFeed.readOfficial(item.id, 1, true);
      if (thread.items.any((reply) =>
          _isAuthor(reply, author) &&
          (html.parseFragment(reply.content).text ?? '').contains(content.trim()))) {
        return;
      }
    }
    throw const FormatException('官网未确认书评已发表；草稿仍保留，请先在官网查看，避免重复提交');
  });

  Future<void> replyReview({
    required int threadId,
    required String content,
  }) => _accountAction('正在回复书评', () async {
    if (threadId <= 0 || content.trim().length < 2) {
      throw const FormatException('书评主题或回复内容无效');
    }
    final author = profile ??= await _readProfile();
    final before = await WenkuReviewFeed.readOfficial(threadId, 1, true);
    final latest = before.totalPages > 1
        ? await WenkuReviewFeed.readOfficial(threadId, before.totalPages, true)
        : before;
    final known = latest.items.map((item) => item.identity).toSet();
    final base = Wenku8HtmlParser.base;
    final url = '${base}modules/article/reviewshow.php?rid=$threadId';
    final source = html.parse(await LegacyTransport.getText(url));
    final form = source.querySelector('form[action*="reviewshow.php"]');
    if (form == null || form.querySelector('textarea[name="pcontent"]') == null) {
      throw const FormatException('官网没有提供可用的回复表单，请先在官网确认');
    }
    final action = Uri.parse(url).resolve(form.attributes['action'] ?? '');
    final aid = int.tryParse(action.queryParameters['aid'] ?? '') ?? 0;
    final endpoint = '$url${aid > 0 ? '&aid=$aid' : ''}';
    await LegacyTransport.officialAction(endpoint, content: content.trim());
    final refreshed = await WenkuReviewFeed.readOfficial(threadId, 1, true);
    final last = refreshed.totalPages > 1
        ? await WenkuReviewFeed.readOfficial(threadId, refreshed.totalPages, true)
        : refreshed;
    if (last.items.any((item) => !known.contains(item.identity) &&
        _isAuthor(item, author) &&
        (html.parseFragment(item.content).text ?? '').contains(content.trim()))) return;
    throw const FormatException('官网未确认回复已发表；草稿仍保留，请先刷新核对，避免重复提交');
  });

  Future<int> mergeCloudToLocal(LibraryState state) =>
      _notRestored('云书架合并');

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    operation = '正在退出文库账号';
    error = null;
    notifyListeners();
    try {
      await LegacyTransport.clearSession();
      authenticated = false;
      profile = null;
      avatar = null;
      cloudBooks = null;
      signedToday = false;
      syncedAt = null;
      _sessionRevision++;
      _publicationRevision++;
    } catch (failure) {
      error = describeError(failure);
      rethrow;
    } finally {
      busy = false;
      operation = null;
      notifyListeners();
    }
  }
}
