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
  const BookSourceSettingsPage({super.key, required this.reduceMotion, this.onLoginCompleted});
  final bool reduceMotion;
  final Future<void> Function()? onLoginCompleted;

  Future<void> _edit(BuildContext context, {BookSourceConfig? source}) async {
    await pushNovelPage<void>(
      context,
      BookSourceEditorPage(source: source, reduceMotion: reduceMotion),
      reduceMotion: reduceMotion,
      slot: ('settings', source == null ? 'add-book-source' : 'edit-book-source-${source.id}'),
    );
  }

  Future<void> _testConnection(BuildContext context, BookSourceConfig source) async {
    try {
      final html = await LegacyTransport.getSourceText(
        source.baseUrl,
        baseUrl: source.baseUrl,
        requestHosts: source.requestHosts,
      );
      if (source.engine == 'lightnovel_fun') {
        try {
          final page = await BookSourceRepository(source).browse(page: 1);
          if (context.mounted) {
            final count = page.items.length;
            showNovelFeedback(
              context,
              count > 0
                  ? '网络与轻之国度首页 API 正常，已读取 $count 条内容'
                  : '网站可连接，但首页 API 返回 0 条书目；请检查登录 token、分类列表或接口数据格式',
            );
          }
        } catch (error) {
          if (context.mounted) {
            showNovelFeedback(
              context,
              '网站首页可连接，但 API 或登录验证失败：' +
                  error.toString().replaceFirst('FormatException: ', ''),
            );
          }
        }
        return;
      }
      if (context.mounted) {
        showNovelFeedback(context, '网站网络连接正常，首页已读取 ' + html.length.toString() + ' 个字符');
      }
    } catch (error) {
      if (context.mounted) {
        showNovelFeedback(
          context,
          error.toString().replaceFirst('FormatException: ', ''),
        );
      }
    }
  }

  Future<void> _login(
    BuildContext context,
    BookSourceStore store,
    BookSourceConfig source,
  ) async {
    try {
      final loginUrl = source.baseUri.resolve(source.loginUrl).toString();
      final accepted = await LegacyTransport.openSourceLogin(
        loginUrl,
        baseUrl: source.baseUrl,
        allowedHosts: source.loginHosts,
      );
      if (accepted) {
        await store.completeSourceLogin(source.id);
        if (store.homepageSourceId == source.id) await onLoginCompleted?.call();
      }
      if (context.mounted) {
        showNovelFeedback(
          context,
          accepted
              ? store.homepageSourceId == source.id && onLoginCompleted != null
                  ? '已完成 ${source.name} 登录，主页正在重新加载'
                  : '已完成 ${source.name} 登录；返回主页后可重新加载书源'
              : '尚未确认登录，请在网站页面完成登录后点击“完成登录”',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showNovelFeedback(context, error.toString().replaceFirst('FormatException: ', ''));
      }
    }
  }

  Future<void> _chooseHomepageSource(
    BuildContext context,
    BookSourceStore store,
  ) async {
    const official = '__official_wenku8__';
    final selected = await showJellySheet<String>(
      context: context,
      reduceMotion: reduceMotion,
      builder: (sheet) {
        Widget option(String id, String title, String subtitle) {
          final active = id == official
              ? store.homepageSourceId == null
              : store.homepageSourceId == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ContentPanel(
              onTap: () => Navigator.pop(sheet, id),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        AppText(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(sheet).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active) const ArchiveIcon(Icons.check_circle, size: 18),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppText(
                '选择主页书源',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const AppText('发现、搜索、作品详情、目录和正文将优先使用所选网站。'),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheet).size.height * .55,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    option(official, '轻小说文库（默认）', 'www.wenku8.cc'),
                    for (final source in store.sources.where((source) => source.supportsReading))
                      option(source.id, source.name, source.baseUrl),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GlassTextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const AppText('取消'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await store.setHomepageSourceId(selected == official ? null : selected);
    if (context.mounted) {
      final name = selected == official
          ? '轻小说文库（默认）'
          : store.byId(selected)?.name ?? '所选书源';
      showNovelFeedback(context, '主页书源已切换为 ${name}');
    }
  }

  Future<void> _remove(BuildContext context, BookSourceStore store, BookSourceConfig source) async {
    final confirmed = await confirmNovelAction(
      context,
      title: '删除这个书源？',
      message: '删除“${source.name}”后，它将不再参与搜索。已缓存的书籍正文和阅读记录不会主动删除。',
      confirmLabel: '删除',
      reduceMotion: reduceMotion,
    );
    if (!confirmed) return;
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
      if (context.mounted) showNovelFeedback(context, '已导入书源：${source.name}');
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
              onTap: () => _chooseHomepageSource(context, store),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          '主页书源',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 7),
                        AppText(
                          store.homepageSource?.name ?? '轻小说文库（默认）',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          store.homepageSource?.baseUrl ?? 'www.wenku8.cc',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 7),
                        AppText(
                          '发现、搜索、详情、目录与正文使用此网站。点击切换。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const ArchiveIcon(CupertinoIcons.chevron_right, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeatureEntry(
              title: '添加自定义书源',
              subtitle: '配置静态网站 CSS 规则；支持已适配网站的专用 API',
              icon: CupertinoIcons.add_circled,
              onTap: () => _edit(context),
            ),
            const SizedBox(height: 10),
            GlassTextButton(
              onPressed: () => _import(context, store),
              child: const AppText('从剪贴板导入书源 JSON'),
            ),
            const SizedBox(height: 20),
            sectionHeader(context, '已配置的网站', '${store.sources.length} / 20'),
            const SizedBox(height: 12),
            if (store.sources.isEmpty)
              ContentPanel(
                child: const AppText('还没有添加其他网站。添加后可先测试解析规则，再手动开启“参与搜索”；未启用的网站不会增加搜索请求。'),
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
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              '参与搜索',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            AppControls.toggle(
                              context,
                              value: source.enabled,
                              onChanged: (value) async {
                                try {
                                  await store.setEnabled(source.id, value);
                                } catch (error) {
                                  if (context.mounted) {
                                    showNovelFeedback(
                                      context,
                                      error.toString().replaceFirst('FormatException: ', ''),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _smallAction(
                          context,
                          '测试连接',
                          () => _testConnection(context, source),
                        ),
                        if (source.loginUrl.trim().isNotEmpty)
                          _smallAction(
                            context,
                            '独立登录',
                            () => _login(context, store, source),
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
              '说明：选择支持阅读的登录网站时，默认同步为主页书源；你仍可在上方手动切换主页。轻之国度使用专用 API，需要有效的轻之国度 token；部分网络线路可能无法直连 lightnovel.fun，遇到 DNS 或 HTTPS 连接失败时请检查该域名的网络路由。各网站 Cookie 按域名隔离，不会与轻小说文库账号混用。其他网站仍需单独适配。',
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
      GlassTextButton(
        compact: true,
        onPressed: onPressed,
        haptic: label == '删除' ? HapticCue.warning : HapticCue.action,
        child: AppText(label),
      );
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
      'loginHosts': TextEditingController(text: source?.loginHosts.join(', ') ?? ''),
      'requestHosts': TextEditingController(text: source?.requestHosts.join(', ') ?? ''),
      'browseUrlTemplate': TextEditingController(text: source?.browseUrlTemplate ?? ''),
      'testKeyword': TextEditingController(text: '测试'),
      'searchUrlTemplate': TextEditingController(text: source?.searchUrlTemplate ?? ''),
      'searchItemSelector': TextEditingController(text: source?.searchItemSelector ?? ''),
      'searchTitleSelector': TextEditingController(text: source?.searchTitleSelector ?? ''),
      'searchLinkSelector': TextEditingController(text: source?.searchLinkSelector ?? ''),
      'searchNextPageSelector': TextEditingController(text: source?.searchNextPageSelector ?? ''),
      'searchAuthorSelector': TextEditingController(text: source?.searchAuthorSelector ?? ''),
      'searchGenreSelector': TextEditingController(text: source?.searchGenreSelector ?? ''),
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
      'chapterNextPageSelector': TextEditingController(text: source?.chapterNextPageSelector ?? ''),
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
        'source-${DateTime.now().microsecondsSinceEpoch}',
    name: _value('name'),
    baseUrl: _value('baseUrl'),
    engine: widget.source?.engine ?? 'css',
    loginUrl: _value('loginUrl'),
    loginHosts: _value('loginHosts')
        .split(RegExp(r'[,，\s]+'))
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet()
        .toList(),
    requestHosts: _value('requestHosts')
        .split(RegExp(r'[,，\s]+'))
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet()
        .toList(),
    browseUrlTemplate: _value('browseUrlTemplate'),
    searchUrlTemplate: _value('searchUrlTemplate'),
    searchItemSelector: _value('searchItemSelector'),
    searchTitleSelector: _value('searchTitleSelector'),
    searchLinkSelector: _value('searchLinkSelector'),
    searchNextPageSelector: _value('searchNextPageSelector'),
    searchAuthorSelector: _value('searchAuthorSelector'),
    searchGenreSelector: _value('searchGenreSelector'),
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
    chapterNextPageSelector: _value('chapterNextPageSelector'),
    chapterContentSelector: _value('chapterContentSelector'),
    imageHosts: _value('imageHosts')
        .split(RegExp(r'[,，\s]+'))
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet()
        .toList(),
    enabled: widget.source?.enabled ?? false,
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
        showNovelFeedback(context, '已保存书源：${config.name}');
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
      final keyword = _value('testKeyword').isEmpty
          ? '测试'
          : _value('testKeyword');
      final repository = BookSourceRepository(config);
      final result = await repository.search(keyword);
      if (result.items.isEmpty) {
        if (mounted) {
          showNovelFeedback(context, '搜索请求成功，但没有解析到书籍；请检查搜索选择器或换一个关键词');
        }
        return;
      }
      final detail = await repository.detail(result.items.first);
      final chapters = await repository.chapters(detail);
      if (chapters.isEmpty) {
        throw const FormatException('目录解析结果为空');
      }
      final body = await repository.chapterContent(chapters.first);
      if (mounted) {
        showNovelFeedback(
          context,
          '测试通过：搜索 ${result.items.length} 条 · 目录 ${chapters.length} 章 · 首章正文 ${body.length} 字',
        );
      }
    } catch (error) {
      if (mounted) {
        showNovelFeedback(context, '测试失败：${error.toString().replaceFirst('FormatException: ', '')}');
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
    padding: const EdgeInsets.only(bottom: 10),
    child: ContentPanel(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _fields[key],
            maxLines: lines,
            keyboardType: keyboard,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 14, height: 1.35),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              alignLabelWithHint: lines > 1,
            ),
          ),
        ],
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
            '填写网站地址和页面解析规则。首页、搜索、API、登录跳转和图片 CDN 分别使用独立域名白名单；只允许 HTTPS 精确主机名，不使用通配符。首页可单独配置发现列表地址，避免把空关键词搜索误当作首页。',
          ),
        ),
        const SizedBox(height: 20),
        sectionHeader(context, '网站与搜索', ''),
        const SizedBox(height: 12),
        _field('name', '网站名称', '例如：某某轻小说'),
        _field('baseUrl', '网站根地址', 'https://example.com/', keyboard: TextInputType.url),
        _field('loginUrl', '登录页面（可选）', '留空表示不需要登录；初始地址必须属于网站根域名', keyboard: TextInputType.url),
        _field('loginHosts', '登录跳转域名白名单（可选）', '只填写 HTTPS 主机名，多个用逗号分隔；用于网站登录时的 www / 根域名或认证跳转'),
        _field('requestHosts', '请求/API 域名白名单（可选）', '只填写 HTTPS 主机名；允许搜索、详情、目录 API 在明确配置的其他域名上访问'),
        _field('browseUrlTemplate', '首页/发现列表地址模板（可选）', '独立于搜索地址；留空时尝试用空关键词搜索。填写时必须包含 {page}'),
        _field('testKeyword', '测试关键词', '输入目标网站中确定存在的小说名称'),
        _field(
          'searchUrlTemplate',
          '搜索地址模板',
          '例如：https://example.com/search?q={keyword}&page={page}；可选 {field}',
          lines: 2,
          keyboard: TextInputType.url,
        ),
        _field('searchItemSelector', '搜索结果容器 CSS', '例如：.book-item'),
        _field('searchTitleSelector', '搜索结果标题 CSS', '例如：.book-title a'),
        _field('searchLinkSelector', '搜索结果链接 CSS（可选）', '例如：a.book-link；留空时自动寻找标题链接'),
        _field('searchNextPageSelector', '搜索下一页 CSS（可选）', '例如：a.next；配置后会按网站分页提示停止搜索'),
        _field('searchAuthorSelector', '搜索结果作者 CSS（可选）', '例如：.author'),
        _field('searchGenreSelector', '搜索结果分类 / 标签 CSS（可选）', '例如：.book-tags'),
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
        _field('chapterNextPageSelector', '目录下一页 CSS（可选）', '例如：a.next；最多自动读取 20 页'),
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
