import 'package:flutter/foundation.dart';
import 'online_component.dart';
import 'package:html/parser.dart' as html;
import 'legacy_transport.dart';
import 'wenku8_html_parser.dart';

class WenkuReview {
  const WenkuReview({
    required this.id,
    required this.user,
    required this.userId,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.replies,
  });
  final int id, userId, replies;
  final String user, title, content, timestamp;
  String get identity => id > 0 ? '$id' : '$userId/$timestamp/$content';
  String get date => RegExp(r'^\d{14}$').hasMatch(timestamp)
      ? '${timestamp.substring(0, 4)}-${timestamp.substring(4, 6)}-${timestamp.substring(6, 8)} ${timestamp.substring(8, 10)}:${timestamp.substring(10, 12)}'
      : timestamp;
}

class WenkuReviewPage {
  const WenkuReviewPage(this.items, this.totalPages);
  final List<WenkuReview> items;
  final int totalPages;
}

typedef ReviewPageReader =
    Future<WenkuReviewPage> Function(int id, int page, bool replies);

class WenkuReviewFeed extends ChangeNotifier {
  WenkuReviewFeed({
    required this.id,
    this.replies = false,
    ReviewPageReader? read,
  }) : _read = read ?? readOfficial;
  static int _urlId(String? href, String field) =>
      int.tryParse(Uri.tryParse(href ?? '')?.queryParameters[field] ?? '') ?? 0;
  static String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static WenkuReviewPage parseOfficial(String markup, int page, bool replies) {
    final root = html.parse(markup);
    final stats = _clean(root.querySelector('#pagestats')?.text ?? '');
    final pages = int.tryParse(RegExp(r'\d+\s*/\s*(\d+)').firstMatch(stats)?.group(1) ?? '') ?? page;
    final datePattern = RegExp(r'\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?');
    final items = <WenkuReview>[];
    if (!replies) {
      for (final row in root.querySelectorAll('tr')) {
        final link = row.querySelector('a[href*="reviewshow.php?rid="]');
        final reviewId = _urlId(link?.attributes['href'], 'rid');
        if (reviewId <= 0 || link == null) continue;
        final user = row.querySelector('a[href*="userpage.php?uid="]');
        var replyCount = 0;
        for (final cell in row.children.where((element) => element.localName == 'td')) {
          final match = RegExp(r'^(\d+)\s*/\s*\d+$').firstMatch(_clean(cell.text));
          if (match != null) replyCount = int.tryParse(match.group(1)!) ?? 0;
        }
        items.add(WenkuReview(id: reviewId, user: _clean(user?.text ?? ''),
          userId: _urlId(user?.attributes['href'], 'uid'), title: _clean(link.text),
          content: '', timestamp: datePattern.firstMatch(_clean(row.text))?.group(0) ?? '',
          replies: replyCount));
      }
      final body = _clean(root.body?.text ?? '');
      if (items.isEmpty &&
          !RegExp(r'暂无.{0,10}书评|没有.{0,10}书评|还没有.{0,10}评论|共\s*0\s*条').hasMatch(body)) {
        throw const FormatException('官网未返回可识别的书评列表，请检查是否已被限流');
      }
    } else {
      for (final table in root.querySelectorAll('table.grid')) {
        if (table.querySelector('textarea') != null) continue;
        final user = table.querySelector('a[href*="userpage.php?uid="]');
        final divs = table.querySelectorAll('div[style*="width:100%"], div[style*="width: 100%"]');
        if (divs.isEmpty) continue;
        final body = divs.last;
        final flat = _clean(table.text);
        final floor = int.tryParse(RegExp(r'(\d+)#').firstMatch(flat)?.group(1) ?? '') ?? items.length + 1;
        items.add(WenkuReview(id: floor, user: _clean(user?.text ?? ''),
          userId: _urlId(user?.attributes['href'], 'uid'),
          title: '', content: body.innerHtml,
          timestamp: datePattern.firstMatch(flat)?.group(0) ?? '', replies: 0));
      }
      if (items.isEmpty) throw const FormatException('官网未返回可识别的书评楼层');
    }
    return WenkuReviewPage(List.unmodifiable(items), pages > page ? pages : page);
  }

  static Future<WenkuReviewPage> readOfficial(int id, int page, bool replies) async {
    if (id <= 0 || page < 1) throw const FormatException('书评编号或页码无效');
    final web = Wenku8HtmlParser.base;
    final url = replies
        ? '${web}modules/article/reviewshow.php?rid=$id&page=$page'
        : '${web}modules/article/reviews.php?aid=$id&type=all&page=$page';
    return parseOfficial(await LegacyTransport.getText(url), page, replies);
  }

  final int id;
  final bool replies;
  final ReviewPageReader _read;
  final _identities = <String>{};
  List<WenkuReview> items = const [];
  int page = 0, totalPages = 0, revision = 0, firstIndex = 0;
  bool loading = false, hasMore = true, requiresLogin = false;
  String? error;
  int _generation = 0;
  bool _disposed = false, _failedRefresh = false;
  Future<void> load({bool refresh = false}) async {
    refresh = refresh || _failedRefresh;
    if (_disposed || (loading && !refresh) || (!refresh && !hasMore)) return;
    final generation = ++_generation;
    final next = refresh ? 1 : page + 1;
    loading = true;
    error = null;
    requiresLogin = false;
    notifyListeners();
    try {
      final result = await _read(id, next, replies);
      if (_disposed || generation != _generation) return;
      final old = refresh ? <WenkuReview>[] : items;
      if (refresh) _identities.clear();
      final added = result.items
          .where((item) => _identities.add(item.identity))
          .toList();
      firstIndex = old.length;
      items = List.unmodifiable([...old, ...added]);
      page = next;
      totalPages = result.totalPages;
      _failedRefresh = false;
      revision++;
      hasMore = next < result.totalPages;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure is FormatException
          ? failure.message.toString()
          : failure is OnlineComponentUnavailable || failure is OnlineAuthenticationRequired || failure is OnlineChallengeRequired
              ? failure.toString()
              : '暂时无法读取书评，请稍后重试';
      requiresLogin = failure is OnlineAuthenticationRequired || failure is OnlineChallengeRequired;
      _failedRefresh = refresh;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
