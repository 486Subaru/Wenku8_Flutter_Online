import 'package:flutter/foundation.dart';

import 'legacy_transport.dart';
import 'library_state.dart';
import 'online_component.dart';
import 'wenku_shelf_sync.dart' show CloudShelfPlan;

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
  Future<void> login(String username, String password) async {
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

  Future<void> connectPublications(String password) => login('', '');

  Future<void> refreshProfile() => initialize();

  Future<T> _notRestored<T>(String feature) async {
    error = '$feature功能正在恢复，当前版本暂未开放';
    notifyListeners();
    throw FormatException(error);
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
  Future<void> postReview({
    required int bookId,
    required String title,
    required String content,
  }) => _notRestored('书评');
  Future<void> replyReview({
    required int threadId,
    required String content,
  }) => _notRestored('书评回复');
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
