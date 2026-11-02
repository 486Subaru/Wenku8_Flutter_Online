import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/wenku8_html_parser.dart';

void main() {
  group('Wenku8HtmlParser', () {
    test('parses book rows and pagination', () {
      const html = '''
        <html><body>
          <div class="book">
            <a href="/book/4265.htm">《测试小说》</a>
            <img src="http://img.wenku8.com/image/4/4265/4265s.jpg">
            <span>作者：测试作者 分类：奇幻 更新：2026-11-01</span>
          </div>
          <a href="articlelist.php?class=1&page=2">2</a>
        </body></html>
      ''';

      final page = Wenku8HtmlParser.parseBookPage(html, 1);
      expect(page.items, hasLength(1));
      expect(page.items.single.id, 4265);
      expect(page.items.single.title, '测试小说');
      expect(page.items.single.author, '测试作者');
      expect(page.items.single.genre, '奇幻');
      expect(
        page.items.single.coverUrl,
        'https://img.wenku8.com/image/4/4265/4265s.jpg',
      );
      expect(page.totalPages, 2);
    });

    test('parses the titled link when a cover-only link comes first', () {
      const html = '''
        <html><body>
          <table class="grid"><tr><td>
            <div style="width:373px;height:136px;">
              <div style="width:95px;">
                <a href="/book/4265.htm" title="测试小说">
                  <img src="http://img.wenku8.com/image/4/4265/4265s.jpg">
                </a>
              </div>
              <div style="margin-top:2px;">
                <b><a href="/book/4265.htm">测试小说</a></b>
                <p>作者:测试作者/分类:奇幻 更新:2026-11-01/字数:90K/连载中</p>
                <p><a href="/modules/article/addbookcase.php?bid=4265">加入书架</a></p>
              </div>
            </div>
          </td></tr></table>
        </body></html>
      ''';

      final books = Wenku8HtmlParser.parseBookList(html);
      expect(books, hasLength(1));
      expect(books.single.id, 4265);
      expect(books.single.title, '测试小说');
      expect(books.single.author, '测试作者');
      expect(books.single.genre, '奇幻');
      expect(books.single.lastUpdate, '2026-11-01');
      expect(
        books.single.coverUrl,
        'https://img.wenku8.com/image/4/4265/4265s.jpg',
      );
    });

    test('parses detail metadata and chapter directory prefix', () {
      const html = '''
        <html>
          <head><title>《测试小说》 - 轻小说文库</title></head>
          <body>
            <div id="content">
              <h1>《测试小说》</h1>
              <table>
                <tr><td>小说作者</td><td>作者乙</td></tr>
                <tr><td>文库分类</td><td>奇幻</td></tr>
                <tr><td>文章状态</td><td>连载中</td></tr>
                <tr><td>最后更新</td><td>2026-11-01</td></tr>
                <tr><td>内容简介</td><td>这是简介内容。</td></tr>
              </table>
              <a href="/novel/4/4265/index.htm">目录</a>
              <img src="http://img.wenku8.com/image/4/4265/4265s.jpg">
            </div>
          </body>
        </html>
      ''';

      final detail = Wenku8HtmlParser.parseBookDetail(html, 4265);
      expect(detail, isNotNull);
      expect(detail!.book.title, '测试小说');
      expect(detail.book.author, '作者乙');
      expect(detail.book.genre, '奇幻');
      expect(detail.book.summary, '这是简介内容。');
      expect(detail.novelPrefix, '/novel/4/4265/');
      expect(detail.book.isComplete, isFalse);
    });

    test('parses volume and chapter rows', () {
      const html = '''
        <html><body>
          <table class="css">
            <tr><td class="vcss">第一卷</td></tr>
            <tr><td class="ccss"><a href="1001.htm">第一章 开始</a></td></tr>
            <tr><td class="ccss"><a href="1002.htm">第二章 继续</a></td></tr>
            <tr><td class="vcss">第二卷</td></tr>
            <tr><td class="ccss"><a href="2001.htm">第三章 新篇</a></td></tr>
          </table>
        </body></html>
      ''';

      final chapters = Wenku8HtmlParser.parseChapterList(html);
      expect(chapters.map((chapter) => chapter.id), [1001, 1002, 2001]);
      expect(chapters.first.volumeId, 1);
      expect(chapters.first.volumeTitle, '第一卷');
      expect(chapters.last.volumeId, 2);
      expect(chapters.last.volumeTitle, '第二卷');
    });

    test('removes chapter navigation and preserves illustration markers', () {
      const html = '''
        <html><body>
          <div id="content">
            <ul id="contentdp"><li>章节导航</li></ul>
            <p>第一段正文。</p>
            <p>第二段正文。<img src="http://img.wenku8.com/image/4/4265/illust.jpg"></p>
            <p><img src="/pictures/4/4265/1001/1.jpg"></p>
          </div>
        </body></html>
      ''';

      final body = Wenku8HtmlParser.parseChapterBody(
        html,
        'https://www.wenku8.cc/novel/4/4265/1001.htm',
      );
      expect(body, contains('第一段正文。'));
      expect(body, contains('第二段正文。'));
      expect(body, contains('<!--image-->https://img.wenku8.com/image/4/4265/illust.jpg<!--image-->'));
      expect(body, contains('<!--image-->https://www.wenku8.cc/pictures/4/4265/1001/1.jpg<!--image-->'));
      expect(body, isNot(contains('章节导航')));
    });
  });
}
