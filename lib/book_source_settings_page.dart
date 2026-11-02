import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_interactions.dart';
import 'app_ui.dart';
import 'book_sources.dart';
import 'legacy_transport.dart';
import 'feature_pages.dart';

class BookSourceSettingsPage extends StatelessWidget {
  const BookSourceSettingsPage({super.key, required this.reduceMotion});
  final bool reduceMotion;

  Future<void> _edit(BuildContext context, {BookSourceConfig? source}) async {
    await pushNovelPage<void>(
      context,
      BookSourceEditorPage(source: source, reduceMotion: reduceMotion),
      reduceMotion: reduceMotion,
      slot: ('settings', source == null ? 'add-book-source' : 'edit-book-source-' + source.id),
    );
  }

  Future<void> _login(BuildContext context, BookSourceConfig source) async {
    try {
      final loginUrl = source.baseUri.resolve(source.loginUrl).toString();
      final accepted = await LegacyTransport.openSourceLogin(
        loginUrl,
        baseUrl: source.baseUrl,
      );
      if (context.mounted) {
        showNovelFeedback(
          context,
          accepted ? '已保存该网站的独立登录状态' : '尚未确认登录，请完成网站登录后重试',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showNovelFeedback(context, error.toString().replaceFirst('FormatException: ', ''));
      }
    }
  }

  Future<void> _remove(BuildContext context, BookSourceStore store, BookSourceConfig source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('删除这个书源？'),
        content: Text('删除“' + source.name + '”后，它将不再参与搜索。已缓存的书籍正文和阅读记录不会主动删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.remove(source.id);
    if (context.mounted) showNovelFeedback(context, '已删除书源配置');
  }

  Future<void> _copy(BuildContext context, BookSourceConfig source) async {
    await Clipboard.setData(ClipboardData(text: jsonEncode(source.toJson())));
    if (context.mounted) showNovelFeedback(context, '书源 JSON 已复制');
  }

  Future<void> _import(BuildContext context, BookSourceStore store) async {
    try {
      final data = await Clipboard.getData('text/plain');
      final decoded = jsonDecode(data?.text ?? '');
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('剪贴板内容不是书源 JSON 对象');
      }
      final source = BookSourceConfig.fromJson(decoded);
      await store.save(source);
      if (context.mounted) showNovelFeedback(context, '已导入书源：' + source.name);
    } catch (error) {
      if (context.mounted) {
        showNovelFeedback(context, error.toString().replaceFirst('FormatException: ', '导入失败：'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = BookSourceStore.instance;
    if (store == null) {
      return const ArchiveFeaturePage(
        title: '书源管理',
        code: 'BOOK SOURCES / CONFIGURATION',
        child: Center(child: AppText('书源管理尚未初始化')),
      );
    }
    return ArchiveFeaturePage(
      title: '书源管理',
      code: 'BOOK SOURCES / CONFIGURATION',
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => ListView(
          padding: featurePadding(context),
          children: [
            ContentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppText(
                    '默认主站 · 轻小说文库',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  AppText('www.wenku8.net · 主站登录、首页与默认发现页保持不变。其他书源独立配置，不会替换主站账号。'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeatureEntry(
              title: '添加自定义书源',
              subtitle: '配置搜索、详情、目录和正文 CSS 规则',
              icon: CupertinoIcons.add_circled,
              onTap: () => _edit(context),
            ),
            const SizedBox(height: 10),
            GlassTextButton(
              onPressed: () => _import(context, store),
              child: const AppText('从剪贴板导入书源 JSON'),
            ),
            const SizedBox(height: 20),
            sectionHeader(context, '已配置的网站', store.sources.length.toString() + ' / 20'),
            const SizedBox(height: 12),
            if (store.sources.isEmpty)
              ContentPanel(
                child: const AppText('还没有添加其他网站。添加书源后，日轻会在搜索时同时查询已启用的网站。'),
              ),
            for (final source in store.sources) ...[
              ContentPanel(
                onTap: () => _edit(context, source: source),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const ArchiveIcon(CupertinoIcons.globe, size: 21),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                source.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              AppText(
                                source.baseUrl,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: source.enabled,
                          onChanged: (value) => store.setEnabled(source.id, value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (source.loginUrl.trim().isNotEmpty)
                          _smallAction(
                            context,
                            '独立登录',
                            () => _login(context, source),
                          ),
                        _smallAction(context, '复制配置', () => _copy(context, source)),
                        _smallAction(context, '删除', () => _remove(context, store, source)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            AppText(
              '说明：当前书源解析面向 HTTPS 静态 HTML 页面，使用 CSS 选择器提取数据。需要复杂 JavaScript 渲染、验证码或特殊接口的网站，可能需要额外适配。书源登录 Cookie 按网站域名隔离。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallAction(BuildContext context, String label, VoidCallback onPressed) =>
      TextButton(onPressed: onPressed, child: Text(label));
}

class BookSourceEditorPage extends StatefulWidget {
  const BookSourceEditorPage({
    super.key,
    this.source,
    required this.reduceMotion,
  });
  final BookSourceConfig? source;
  final bool reduceMotion;

  @override
  State<BookSourceEditorPage> createState() => _BookSourceEditorPageState();
}

class _BookSourceEditorPageState extends State<BookSourceEditorPage> {
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _fields = {
      'name': TextEditingController(text: source?.name ?? ''),
      'baseUrl': TextEditingController(text: source?.baseUrl ?? ''),
      'loginUrl': TextEditingController(text: source?.loginUrl ?? ''),
      'searchUrlTemplate': TextEditingController(text: source?.searchUrlTemplate ?? ''),
      'searchItemSelector': TextEditingController(text: source?.searchItemSelector ?? ''),
      'searchTitleSelector': TextEditingController(text: source?.searchTitleSelector ?? ''),
      'searchLinkSelector': TextEditingController(text: source?.searchLinkSelector ?? ''),
      'searchAuthorSelector': TextEditingController(text: source?.searchAuthorSelector ?? ''),
      'searchSummarySelector': TextEditingController(text: source?.searchSummarySelector ?? ''),
      'searchCoverSelector': TextEditingController(text: source?.searchCoverSelector ?? ''),
      'searchCoverAttribute': TextEditingController(text: source?.searchCoverAttribute ?? 'src'),
      'detailTitleSelector': TextEditingController(text: source?.detailTitleSelector ?? ''),
      'detailAuthorSelector': TextEditingController(text: source?.detailAuthorSelector ?? ''),
      'detailSummarySelector': TextEditingController(text: source?.detailSummarySelector ?? ''),
      'detailGenreSelector': TextEditingController(text: source?.detailGenreSelector ?? ''),
      'detailStatusSelector': TextEditingController(text: source?.detailStatusSelector ?? ''),
      'detailCoverSelector': TextEditingController(text: source?.detailCoverSelector ?? ''),
      'detailCoverAttribute': TextEditingController(text: source?.detailCoverAttribute ?? 'src'),
      'chapterListUrlTemplate': TextEditingController(text: source?.chapterListUrlTemplate ?? ''),
      'chapterItemSelector': TextEditingController(text: source?.chapterItemSelector ?? ''),
      'chapterTitleSelector': TextEditingController(text: source?.chapterTitleSelector ?? ''),
      'chapterHrefSelector': TextEditingController(text: source?.chapterHrefSelector ?? 'a[href]'),
      'chapterContentSelector': TextEditingController(text: source?.chapterContentSelector ?? ''),
      'imageHosts': TextEditingController(text: source?.imageHosts.join(', ') ?? ''),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _fields[key]!.text.trim();

  BookSourceConfig _config() => BookSourceConfig(
    id: widget.source?.id ??
        'source-' + DateTime.now().microsecondsSinceEpoch.toString(),
    name: _value('name'),
    baseUrl: _value('baseUrl'),
    loginUrl: _value('loginUrl'),
    searchUrlTemplate: _value('searchUrlTemplate'),
    searchItemSelector: _value('searchItemSelector'),
    searchTitleSelector: _value('searchTitleSelector'),
    searchLinkSelector: _value('searchLinkSelector'),
    searchAuthorSelector: _value('searchAuthorSelector'),
    searchSummarySelector: _value('searchSummarySelector'),
    searchCoverSelector: _value('searchCoverSelector'),
    searchCoverAttribute: _value('searchCoverAttribute').isEmpty
        ? 'src'
        : _value('searchCoverAttribute'),
    detailTitleSelector: _value('detailTitleSelector'),
    detailAuthorSelector: _value('detailAuthorSelector'),
    detailSummarySelector: _value('detailSummarySelector'),
    detailGenreSelector: _value('detailGenreSelector'),
    detailStatusSelector: _value('detailStatusSelector'),
    detailCoverSelector: _value('detailCoverSelector'),
    detailCoverAttribute: _value('detailCoverAttribute').isEmpty
        ? 'src'
        : _value('detailCoverAttribute'),
    chapterListUrlTemplate: _value('chapterListUrlTemplate'),
    chapterItemSelector: _value('chapterItemSelector'),
    chapterTitleSelector: _value('chapterTitleSelector'),
    chapterHrefSelector: _value('chapterHrefSelector').isEmpty
        ? 'a[href]'
        : _value('chapterHrefSelector'),
    chapterContentSelector: _value('chapterContentSelector'),
    imageHosts: _value('imageHosts')
        .split(RegExp(r'[,，\s]+'))
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet()
        .toList(),
    enabled: widget.source?.enabled ?? true,
  );

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final config = _config();
      config.validate();
      final store = BookSourceStore.instance;
      if (store == null) throw const FormatException('书源管理尚未初始化');
      await store.save(config);
      if (mounted) {
        showNovelFeedback(context, '已保存书源：' + config.name);
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        showNovelFeedback(context, error.toString().replaceFirst('FormatException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      final config = _config();
      config.validate();
      final result = await BookSourceRepository(config).search('测试');
      if (mounted) {
        showNovelFeedback(
          context,
          '连接成功，解析到 ' + result.items.length.toString() + ' 条搜索结果',
        );
      }
    } catch (error) {
      if (mounted) {
        showNovelFeedback(context, '测试失败：' + error.toString().replaceFirst('FormatException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _field(
    String key,
    String label,
    String hint, {
    int lines = 1,
    TextInputType keyboard = TextInputType.text,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _fields[key],
      maxLines: lines,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: lines > 1,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ArchiveFeaturePage(
    title: widget.source == null ? '添加书源' : '编辑书源',
    code: 'BOOK SOURCE / CSS RULES',
    child: ListView(
      padding: featurePadding(context),
      children: [
        ContentPanel(
          child: const AppText(
            '填写网站地址和页面解析规则。搜索地址支持 {keyword} 与 {page}；目录地址模板支持 {bookUrl}。所有页面请求限制在该书源的 HTTPS 主域名，图片可额外配置 CDN 域名。',
          ),
        ),
        const SizedBox(height: 20),
        sectionHeader(context, '网站与搜索', ''),
        const SizedBox(height: 12),
        _field('name', '网站名称', '例如：某某轻小说'),
        _field('baseUrl', '网站根地址', 'https://example.com/', keyboard: TextInputType.url),
        _field('loginUrl', '登录页面（可选）', '留空表示不需要登录；必须与网站使用同一域名', keyboard: TextInputType.url),
        _field(
          'searchUrlTemplate',
          '搜索地址模板',
          '例如：https://example.com/search?q={keyword}&page={page}',
          lines: 2,
          keyboard: TextInputType.url,
        ),
        _field('searchItemSelector', '搜索结果容器 CSS', '例如：.book-item'),
        _field('searchTitleSelector', '搜索结果标题 CSS', '例如：.book-title a'),
        _field('searchLinkSelector', '搜索结果链接 CSS（可选）', '例如：a.book-link；留空时自动寻找标题链接'),
        _field('searchAuthorSelector', '搜索结果作者 CSS（可选）', '例如：.author'),
        _field('searchSummarySelector', '搜索结果简介 CSS（可选）', '例如：.intro'),
        _field('searchCoverSelector', '搜索结果封面 CSS（可选）', '例如：img.cover'),
        _field('searchCoverAttribute', '搜索结果封面属性', '通常为 src；懒加载图片可填 data-src'),
        const SizedBox(height: 12),
        sectionHeader(context, '详情页信息（可选）', ''),
        const SizedBox(height: 12),
        _field('detailTitleSelector', '书名 CSS', '例如：h1.book-title'),
        _field('detailAuthorSelector', '作者 CSS', '例如：.book-author'),
        _field('detailSummarySelector', '简介 CSS', '例如：.book-intro'),
        _field('detailGenreSelector', '分类 / 标签 CSS', '例如：.book-tags'),
        _field('detailStatusSelector', '完结状态 CSS', '例如：.book-status；文本含“完结”时标记为完结'),
        _field('detailCoverSelector', '详情封面 CSS', '例如：.book-cover img'),
        _field('detailCoverAttribute', '详情封面属性', '通常为 src 或 data-src'),
        const SizedBox(height: 12),
        sectionHeader(context, '目录与正文', ''),
        const SizedBox(height: 12),
        _field(
          'chapterListUrlTemplate',
          '目录页面地址模板（可选）',
          '留空时使用详情页；可用 {bookUrl} 代表书籍详情页地址',
          lines: 2,
          keyboard: TextInputType.url,
        ),
        _field('chapterItemSelector', '章节条目 CSS', '例如：#chapter-list a 或 .chapter-item'),
        _field('chapterTitleSelector', '章节标题 CSS（可选）', '例如：.chapter-title；留空时使用条目文本'),
        _field('chapterHrefSelector', '章节链接 CSS', '通常为 a[href]'),
        _field(
          'chapterContentSelector',
          '正文容器 CSS',
          '例如：#content 或 .chapter-content',
        ),
        _field('imageHosts', '图片 CDN 域名（可选）', '多个域名用逗号分隔，不要填写 https://'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GlassTextButton(
                onPressed: _testing || _saving ? null : _test,
                child: AppText(_testing ? '正在测试…' : '测试搜索'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassTextButton(
                onPressed: _saving || _testing ? null : _save,
                child: AppText(_saving ? '正在保存…' : '保存书源'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
