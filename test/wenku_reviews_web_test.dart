import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:wenku8_flutter/wenku_reviews.dart';
import 'package:wenku8_flutter/legacy_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official reviews parse title, author and reply count', () {
    const source = '<table><tr><td><a href="reviewshow.php?rid=98">讨论主题</a></td>'
        '<td>3/12</td><td><a href="userpage.php?uid=7">读者</a></td></tr></table>'
        '<div id="pagestats">1/4</div>';
    final found = WenkuReviewFeed.parseOfficial(source, 1, false);
    expect(found.items.single.id, 98);
    expect(found.items.single.title, '讨论主题');
    expect(found.items.single.replies, 3);
    expect(found.items.single.userId, 7);
    expect(found.totalPages, 4);
  });

  test('individual review floors do not overwrite each other', () {
    const source = '<table class="grid"><tr><td>1#'
        '<a href="userpage.php?uid=7">读者</a>'
        '<div style="width:100%">第一楼</div></td></tr></table>'
        '<table class="grid"><tr><td>2#'
        '<div style="width:100%"><b>第二楼</b></div></td></tr></table>';
    final found = WenkuReviewFeed.parseOfficial(source, 1, true);
    expect(found.items.map((item) => item.identity).toSet().length, 2);
    expect(found.items.last.content, contains('<b>第二楼</b>'));
  });

  test('Cloudflare 1015 error does not become zero reviews', () {
    expect(() => WenkuReviewFeed.parseOfficial('<title>Error 1015</title>', 1, false), throwsFormatException);
  });

  test('reading reviews calls the official web channel', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      expect(call.method, 'getText');
      expect((call.arguments as Map)['url'], contains('reviews.php?aid=111&type=all&page=2'));
      return '<a href="reviewshow.php?rid=98">讨论主题</a>'
          '<table><tr><td><a href="reviewshow.php?rid=98">讨论主题</a></td>'
          '<td>0/1</td></tr></table><div id="pagestats">2/2</div>';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));
    final result = await WenkuReviewFeed.readOfficial(111, 2, false);
    expect(result.items.single.id, 98);
    expect(result.totalPages, 2);
  });
}
