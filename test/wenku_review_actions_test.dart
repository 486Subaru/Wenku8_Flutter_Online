import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/wenku_account.dart';
import 'package:wenku8_flutter/legacy_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official profile table fields are parsed from input and text cells', () {
    const html = '<table><tr><td>用户ID</td><td>7</td></tr>'
        '<tr><td>用户名</td><td>reader</td></tr>'
        '<tr><td>昵称</td><td><input value="读者"></td></tr>'
        '<tr><td>现有积分</td><td>123</td></tr></table>';
    final profile = WenkuAccount.parseOfficialProfile(html);
    expect(profile.id, 7);
    expect(profile.displayName, '读者');
    expect(profile.score, 123);
    expect(() => WenkuAccount.parseOfficialProfile('<html>Error 1015</html>'), throwsFormatException);
  });

  test('uncertain book review POST is never replayed automatically', () async {
    final account = WenkuAccount()
      ..authenticated = true
      ..profile = const WenkuProfile(id: 7, username: 'reader', nickname: '读者',
        score: 0, experience: 0, rank: '');
    var postCount = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      if (call.method == 'hasSession') return true;
      if (call.method == 'officialAction') {
        postCount++;
        return '<html>网站响应</html>';
      }
      if (call.method == 'getText') {
        return '<table><tr><td><a href="reviewshow.php?rid=22">已有评论</a></td>'
            '<td>0/1</td><td><a href="userpage.php?uid=8">其他用户</a></td></tr></table>';
      }
      throw StateError('Unexpected web method');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));
    await expectLater(
      account.postReview(bookId: 111, title: '测试', content: '十个字以上的可验证评论内容'),
      throwsFormatException,
    );
    expect(postCount, 1);
    expect(account.busy, false);
    expect(account.error, contains('未确认'));
  });

  test('reply refuses to submit without a verified website form', () async {
    final account = WenkuAccount()
      ..authenticated = true
      ..profile = const WenkuProfile(id: 7, username: 'reader', nickname: '读者',
        score: 0, experience: 0, rank: '');
    var actions = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      if (call.method == 'hasSession') return true;
      if (call.method == 'officialAction') {
        actions++;
        return 'ok';
      }
      if (call.method == 'getText') {
        if ((call.arguments as Map)['url'].toString().contains('page=')) {
          return '<table class="grid"><tr><td>1#'
              '<div style="width:100%">评论正文</div></td></tr></table>';
        }
        return '<html>没有回复表单</html>';
      }
      throw StateError('Unexpected web method');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));
    await expectLater(account.replyReview(threadId: 22, content: '回复内容'), throwsFormatException);
    expect(actions, 0);
  });
}
