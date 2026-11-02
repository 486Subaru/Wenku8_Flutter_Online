import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_ui.dart';
import 'catalog.dart';
import 'book_sources.dart';
import 'legacy_transport.dart';
import 'library_state.dart';
import 'library_workspace.dart';
import 'novel_feed_controller.dart';
import 'pages.dart' show DiscoverPage, openDetail;
import 'publication_catalog.dart';
import 'wenku_account.dart';
import 'online_component.dart';
import 'wenku_features.dart';
import 'web_publication_catalog.dart';

Future<bool> confirmNovelAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool reduceMotion = false,
}) async =>
    await showJellySheet<bool>(
      context: context,
      reduceMotion: reduceMotion,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            AppText(message),
            const SizedBox(height: 24),
            GlassTextButton(
              onPressed: () => Navigator.pop(sheet, true),
              haptic: HapticCue.warning,
              child: AppText(confirmLabel),
            ),
            const SizedBox(height: 8),
            GlassTextButton(
              onPressed: () => Navigator.pop(sheet, false),
              child: const AppText('取消'),
            ),
          ],
        ),
      ),
    ) ==
    true;

class ArchiveFeaturePage extends StatelessWidget {
  const ArchiveFeaturePage({
    super.key,
    required this.title,
    required this.code,
    required this.child,
    this.actions = const [],
    this.canPop = true,
  });
  final String title, code;
  final Widget child;
  final List<Widget> actions;
  final bool canPop;
  @override
  Widget build(BuildContext context) => LibraryWorkspace(
    child: Scaffold(
      body: Atmosphere(
        child: GlassHeaderLayout(
          header: ArchiveHeaderBar(
            leading: GlassIconButton(
              icon: CupertinoIcons.back,
              label: '返回',
              onPressed: canPop ? () => Navigator.pop(context) : null,
            ),
            title: ArchiveRouteTitle(title: title, code: code),
            actions: actions,
          ),
          body: child,
        ),
      ),
    ),
  );
}

EdgeInsets featurePadding(BuildContext context) => EdgeInsets.fromLTRB(
  24,
  MediaQuery.paddingOf(context).top + FrostedHeader.toolbarHeight + 20,
  24,
  MediaQuery.paddingOf(context).bottom + 32,
);

class FeatureEntry extends StatelessWidget {
  const FeatureEntry({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ContentPanel(
    onTap: onTap,
    child: ArchivePart(
      start: .18,
      end: .84,
      travel: const Offset(0, 6),
      child: Row(
        children: [
          ArchiveIcon(icon, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  AppText(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const ArchiveIcon(CupertinoIcons.chevron_right, size: 14),
        ],
      ),
    ),
  );
}

class FeatureError extends StatelessWidget {
  const FeatureError(this.text, {super.key});
  final String? text;
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Semantics(
            liveRegion: true,
            child: AppText(
              text!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}

class WenkuAccountPage extends StatefulWidget {
  const WenkuAccountPage({
    super.key,
    required this.account,
    required this.state,
    required this.repository,
  });
  final WenkuAccount account;
  final LibraryState state;
  final NovelRepository repository;
  @override
  State<WenkuAccountPage> createState() => _WenkuAccountPageState();
}

class _WenkuAccountPageState extends State<WenkuAccountPage> {
  bool _sourceLoginBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.account.initialize());
    });
  }

  Future<void> _run(Future<void> Function() work, String success) async {
    if (widget.account.busy) return;
    try {
      await work();
      if (mounted) showNovelFeedback(context, success);
    } catch (_) {
      // The account's live region displays the concrete failure.
    }
  }

  Future<void> _chooseLoginSource() async {
    final store = BookSourceStore.instance;
    if (store == null) return;
    const official = '__official_wenku8__';
    final selected = await showJellySheet<String>(
      context: context,
      reduceMotion: widget.state.reduceMotion,
      builder: (sheet) {
        Widget option(String id, String title, String subtitle) {
          final active = id == official
              ? store.loginSourceId == null
              : store.loginSourceId == id;
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
                '选择登录网站',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const AppText('默认使用轻小说文库，也可以选择已配置独立登录网址的书源。'),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheet).size.height * .55,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    option(official, '轻小说文库（默认）', 'www.wenku8.net'),
                    for (final source in store.loginSources)
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
    try {
      await store.setLoginSourceId(selected == official ? null : selected);
      if (mounted) {
        final name = selected == official
            ? '轻小说文库（默认）'
            : store.byId(selected)?.name ?? '所选网站';
        showNovelFeedback(context, '登录网站已切换为 $name，主页书源已同步');
      }
    } catch (error) {
      if (mounted) {
        showNovelFeedback(context, error.toString().replaceFirst('FormatException: ', ''));
      }
    }
  }

  Future<void> _login() async {
    final store = BookSourceStore.instance;
    final source = store?.loginSource;
    if (source == null) {
      await _run(() async {
        await widget.account.login('', '');
        await store?.completeOfficialLogin();
      }, '已完成文库官网登录');
      return;
    }
    if (_sourceLoginBusy || widget.account.busy) return;
    setState(() => _sourceLoginBusy = true);
    try {
      final accepted = await LegacyTransport.openSourceLogin(
        source.baseUri.resolve(source.loginUrl).toString(),
        baseUrl: source.baseUrl,
      );
      if (!accepted) {
        if (mounted) {
          showNovelFeedback(context, '尚未确认登录，请在网站页面完成登录后点击“完成登录”');
        }
        return;
      }
      await store!.completeSourceLogin(source.id);
      if (mounted) {
        showNovelFeedback(context, '已完成 ${source.name} 登录，主页书源已切换');
      }
    } catch (error) {
      if (mounted) {
        showNovelFeedback(context, error.toString().replaceFirst('FormatException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sourceLoginBusy = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await confirmNovelAction(
      context,
      title: '退出账号？',
      message: '只清除文库官网登录状态，本机书架、阅读进度、书签与离线章节均保留。',
      confirmLabel: '退出账号',
      reduceMotion: widget.state.reduceMotion,
    );
    if (confirmed) {
      await _run(() async {
        await widget.account.logout();
        await BookSourceStore.instance?.completeOfficialLogin();
      }, '已退出账号');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = BookSourceStore.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.account, ?store]),
      builder: (context, _) {
        final account = widget.account;
        final loginSource = store?.loginSource;
        final sourceName = loginSource?.name ?? '轻小说文库';
        final connected = loginSource == null
            ? account.authenticated
            : store!.isSourceLoggedIn(loginSource.id);
        final busy = account.busy || _sourceLoginBusy;
        return ArchiveFeaturePage(
          title: '账号登录',
          code: 'ACCOUNT / SOURCE LOGIN',
          child: LoadedContentSequence(
            generation: (loginSource?.id, connected),
            child: ListView(
              key: ValueKey((loginSource?.id, connected)),
              padding: featurePadding(context),
              children: [
                ContentPanel(
                  onTap: busy || store == null ? null : _chooseLoginSource,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText(
                              '登录网站',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            AppText(
                              loginSource?.name ?? '轻小说文库（默认）',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              loginSource?.baseUrl ?? 'www.wenku8.net',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const ArchiveIcon(CupertinoIcons.chevron_right, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppText(
                  connected ? '已连接 $sourceName 账号' : '连接 $sourceName 账号',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                AppText(
                  loginSource == null
                      ? connected
                          ? '文库官网登录状态已保存在本机。在线书目与阅读使用文库主站。'
                          : '打开文库官网后，在网站页面完成登录或注册。账号密码和网站验证都由官网处理。'
                      : connected
                          ? '${loginSource.name} 的独立登录状态已保存。主页书源已同步到该网站。'
                          : '登录将在该网站的独立页面中完成。该网站 Cookie 与文库主站分开保存；选择此网站后，主页书源也会同步切换。',
                ),
                const SizedBox(height: 24),
                if (!connected)
                  ContentPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassTextButton(
                          key: const ValueKey('account-login'),
                          onPressed: busy ? null : _login,
                          child: AppText('打开 $sourceName 登录'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ContentPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ArchiveCode('SESSION / READY'),
                        const SizedBox(height: 10),
                        AppText(
                          loginSource == null
                              ? '在线书目、搜索和章节阅读将使用文库主站会话。'
                              : '该网站的登录 Cookie 独立保存，不会覆盖文库主站账号。',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassTextButton(
                    key: const ValueKey('account-reverify'),
                    onPressed: busy ? null : _login,
                    child: AppText('重新打开 $sourceName'),
                  ),
                  if (loginSource == null) ...[
                    const SizedBox(height: 12),
                    GlassTextButton(
                      key: const ValueKey('account-logout'),
                      onPressed: busy ? null : _logout,
                      child: const AppText('退出账号'),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    AppText(
                      '如需更换此网站的账号，请在网站页面自行退出后重新登录。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                if (busy) ...[
                  const SizedBox(height: 20),
                  const InlineSkeleton(label: '正在处理账号操作'),
                  const SizedBox(height: 10),
                  AppText(account.operation ?? '正在打开登录网站'),
                ],
                FeatureError(loginSource == null ? account.error : null),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CloudBookshelfPage extends StatefulWidget {
  const CloudBookshelfPage({
    super.key,
    required this.account,
    required this.state,
    required this.repository,
  });
  final WenkuAccount account;
  final LibraryState state;
  final NovelRepository repository;
  @override
  State<CloudBookshelfPage> createState() => _CloudBookshelfPageState();
}

class _CloudBookshelfPageState extends State<CloudBookshelfPage> {
  String? _localError;
  bool _merging = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (widget.account.busy) return;
    try {
      final sync = WenkuFeaturesScope.maybeOf(context)?.shelfSync;
      if (sync != null) {
        await sync.synchronize();
        return;
      }
      await widget.account.refreshCloud();
    } catch (_) {}
  }

  Future<void> _merge() async {
    if (_merging || widget.account.busy) return;
    final confirmed = await confirmNovelAction(
      context,
      title: '合并云书架到本机？',
      message: '添加云端收藏。本机已有书籍、进度、书签和缓存保持不变。',
      confirmLabel: '合并收藏',
      reduceMotion: widget.state.reduceMotion,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _merging = true;
      _localError = null;
    });
    try {
      final count = await widget.account.mergeCloudToLocal(widget.state);
      if (mounted) showNovelFeedback(context, '已添加 $count 本云端收藏到本机');
    } catch (error) {
      if (mounted) {
        setState(() => _localError = WenkuAccount.describeError(error));
      }
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  Future<void> _upload() async {
    if (_merging || widget.account.busy) return;
    final confirmed = await confirmNovelAction(
      context,
      title: '合并本机收藏到云端？',
      message: '仅上传云端没有的本机收藏。不会删除云端书籍，也不上传正文或阅读记录。',
      confirmLabel: '合并到云端',
      reduceMotion: widget.state.reduceMotion,
    );
    if (!confirmed || !mounted) return;
    try {
      final result = await widget.account.uploadMissing(widget.state.shelf);
      if (mounted) {
        showNovelFeedback(
          context,
          result.remaining.isEmpty
              ? '云书架已合并 · 新增 ${result.uploaded.length} 本'
              : '已完成 ${result.uploaded.length} 本，剩余 ${result.remaining.length} 本可重试',
        );
      }
    } catch (_) {}
  }

  Future<void> _remove(CloudBook book) async {
    if (widget.account.busy || _merging) return;
    final confirmed = await confirmNovelAction(
      context,
      title: '移出云书架？',
      message:
          '「${book.title.isEmpty ? '书籍 ${book.id}' : book.title}」的本机收藏、进度及缓存仍保留。',
      confirmLabel: '移出云书架',
      reduceMotion: widget.state.reduceMotion,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.account.removeCloud(book.id);
    } catch (_) {}
  }

  Future<void> _open(CloudBook book) async {
    final novel =
        widget.state.cachedNovel(book.id) ??
        Novel(
          id: book.id,
          title: book.title.isEmpty ? '书籍 ${book.id}' : book.title,
          author: '',
          genre: '轻小说',
          summary: '',
          colors: const [Color(0xFF202020), Color(0xFF333333)],
          lastUpdate: book.updated,
        );
    openDetail(context, novel, widget.state, widget.repository);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.account,
      widget.state,
      ?WenkuFeaturesScope.maybeOf(context)?.shelfSync,
    ]),
    builder: (context, _) {
      final account = widget.account;
      final books = account.cloudBooks;
      final busy = account.busy || _merging;
      final sync = WenkuFeaturesScope.maybeOf(context)?.shelfSync;
      return ArchiveFeaturePage(
        title: '云书架',
        code: 'CLOUD / COLLECTION',
        actions: [
          GlassIconButton(
            icon: CupertinoIcons.refresh,
            label: '刷新云书架',
            onPressed: busy ? null : _refresh,
          ),
        ],
        child: LoadedContentSequence(
          generation: books,
          child: ListView.builder(
            padding: featurePadding(context),
            itemCount: 1 + (books?.length ?? 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sectionHeader(
                      context,
                      '云端收藏',
                      books == null ? '' : '${books.length} 本',
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      sync == null
                          ? '两端只合并收藏，阅读进度与本地文件保留。'
                          : sync.syncing
                          ? '正在自动同步收藏'
                          : sync.error != null
                          ? '自动同步待重试 · ${sync.error}'
                          : '收藏自动同步 · 联网或回到前台时自动更新',
                    ),
                    const SizedBox(height: 16),
                    if (sync == null)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          GlassTextButton(
                            key: const ValueKey('cloud-download'),
                            onPressed: busy || books == null ? null : _merge,
                            child: const AppText('合并到本机'),
                          ),
                          GlassTextButton(
                            key: const ValueKey('cloud-upload'),
                            onPressed: busy || books == null ? null : _upload,
                            child: const AppText('合并到云端'),
                          ),
                        ],
                      ),
                    FeatureError(_localError ?? account.error),
                    if (busy)
                      const SizedBox(
                        height: 72,
                        child: LoadingSkeleton(layout: SkeletonLayout.actions),
                      ),
                    if (books?.isEmpty == true)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: AppText('云书架还没有收藏')),
                      ),
                    const SizedBox(height: 20),
                  ],
                );
              }
              final book = books![index - 1];
              return LoadedContentItem(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ContentPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _open(book),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  book.title.isEmpty
                                      ? '书籍 ${book.id}'
                                      : book.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (book.latestChapter.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  AppText(
                                    book.latestChapter,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                ArchiveCode(
                                  '${book.updated}  /  ${widget.state.contains(book.id) ? 'LOCAL + CLOUD' : 'CLOUD'}',
                                ),
                              ],
                            ),
                          ),
                        ),
                        GlassIconButton(
                          icon: CupertinoIcons.minus_circle,
                          label: '移出云书架 ${book.id}',
                          onPressed: busy ? null : () => _remove(book),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class PublicationLibraryPage extends StatefulWidget {
  const PublicationLibraryPage({
    super.key,
    required this.catalog,
    required this.repository,
    required this.state,
    this.account,
  });
  final PublicationCatalog catalog;
  final NovelRepository repository;
  final LibraryState state;
  final WenkuAccount? account;
  @override
  State<PublicationLibraryPage> createState() => _PublicationLibraryPageState();
}

class _PublicationLibraryPageState extends State<PublicationLibraryPage> {
  List<PublicationLibrary> _libraries = const [];
  PublicationLibrary? _selected;
  NovelFeedController? _feed;
  String? _error;
  bool _needsLogin = false;
  late int _accountRevision;
  late int _publicationRevision;
  late bool _authenticated;
  bool _accountPageOpen = false;
  @override
  void initState() {
    super.initState();
    _accountRevision = widget.account?.sessionRevision ?? 0;
    _publicationRevision = widget.account?.publicationRevision ?? 0;
    _authenticated = widget.account?.authenticated ?? false;
    widget.account?.addListener(_accountChanged);
    unawaited(_load());
  }

  void _accountChanged() {
    final account = widget.account;
    if (account == null || !mounted || _accountPageOpen || account.busy) return;
    if (_accountRevision == account.sessionRevision &&
        _authenticated == account.authenticated &&
        _publicationRevision == account.publicationRevision) {
      return;
    }
    _accountRevision = account.sessionRevision;
    _publicationRevision = account.publicationRevision;
    _authenticated = account.authenticated;
    final library = _selected;
    if (library != null) _select(library, force: true);
  }

  @override
  void didUpdateWidget(PublicationLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      oldWidget.account?.removeListener(_accountChanged);
      widget.account?.addListener(_accountChanged);
      _accountChanged();
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _needsLogin = false;
    });
    try {
      // Restoring the shared account is part of entering this catalogue, not a
      // reason to issue a guest request and replace it again after restoration.
      await widget.account?.initialize();
      final libraries = await widget.catalog.publicationLibraries(
        refresh: true,
      );
      if (mounted) {
        _libraries = libraries;
        _select(libraries.first);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = WenkuAccount.describeError(error);
          _needsLogin = error is OnlineAuthenticationRequired ||
              error is OnlineChallengeRequired;
        });
      }
    }
  }

  void _select(PublicationLibrary library, {bool force = false}) {
    if (!force && _selected?.id == library.id) return;
    _feed?.dispose();
    setState(() {
      _selected = library;
      _feed = NovelFeedController(
        PublicationNovelRepository(widget.repository, widget.catalog, library),
        initialItems: 60,
      );
    });
    if (force) {
      unawaited(_feed!.refresh());
    } else {
      _feed!.loadInitial();
    }
  }

  Future<void> _choose(BuildContext anchor) async {
    final selected = await showGlassMenu<PublicationLibrary>(
      context: anchor,
      reduceMotion: widget.state.reduceMotion,
      builder: (menuContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(menuContext).height * .62,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, library) in _libraries.indexed)
                GlassMenuItem(
                  order: index,
                  label: library.name,
                  selected: _selected?.id == library.id,
                  onPressed: () => Navigator.pop(menuContext, library),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) _select(selected);
  }

  Future<void> _loginForLibrary() async {
    final account = widget.account;
    if (account == null || _accountPageOpen) return;
    _accountPageOpen = true;
    try {
      await pushNovelPage<void>(
        context,
        WenkuAccountPage(
          account: account,
          state: widget.state,
          repository: widget.repository,
        ),
        reduceMotion: widget.state.reduceMotion,
      );
    } finally {
      if (mounted) {
        setState(() => _accountPageOpen = false);
        // One refresh, after login settles and this route becomes visible.
        // Returning early waits for the account's completion notification.
        _accountChanged();
      }
    }
  }

  Widget _catalogBody(BuildContext context) {
    final account = widget.account;
    if (account != null &&
        account.busy &&
        (_accountRevision != account.sessionRevision ||
            _authenticated != account.authenticated)) {
      return const LibrarySkeleton();
    }
    final failure = _feed?.error;
    if (failure is PublicationConnectionRequired && widget.account != null) {
      return ContentNotice(
        icon: CupertinoIcons.person_crop_circle,
        title: widget.account!.authenticated ? '出版分类暂时不可用' : '此分类需要文库账号',
        message: widget.account!.authenticated
            ? '已复用当前账号请求分类，但官网未接受这次会话。可稍后重试，账号与阅读记录仍保留。'
            : '登录后可读取官网出版分类。搜索和排行榜仍可直接使用。',
        actionLabel: widget.account!.authenticated ? '重新加载' : '登录账号',
        onRetry: widget.account!.authenticated
            ? () => _select(_selected!, force: true)
            : _loginForLibrary,
      );
    }
    if (failure is FormatException && _feed!.items.isEmpty) {
      return ContentNotice(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: '出版分类暂时不可用',
        message: failure.message,
        onRetry: _feed!.retry,
      );
    }
    if ((failure is OnlineAuthenticationRequired ||
            failure is OnlineChallengeRequired) &&
        widget.account != null) {
      return ContentNotice(
        icon: CupertinoIcons.person_crop_circle,
        title: failure is OnlineChallengeRequired
            ? '需要完成官网验证'
            : '需要重新连接文库账号',
        message: failure is OnlineChallengeRequired
            ? '请打开文库官网页面完成验证，再重新加载分类。'
            : '当前官网会话无效或已过期。请重新登录后再读取分类。',
        actionLabel: '打开官网登录',
        onRetry: _loginForLibrary,
      );
    }
    return DiscoverPage(
      key: ValueKey(_selected!.id),
      books: const [],
      state: widget.state,
      repository: widget.repository,
      onSearch: () {},
      showHeader: false,
      feed: _feed,
      categoryTitle: _selected!.name,
      onChooseCategory: _choose,
    );
  }

  @override
  void dispose() {
    widget.account?.removeListener(_accountChanged);
    _feed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ArchiveFeaturePage(
    title: '出版文库',
    code: 'CATALOG / PUBLICATION',
    child: _selected == null
        ? (_error != null
              ? ContentNotice(
                  icon: CupertinoIcons.wifi_exclamationmark,
                  title: _needsLogin ? '需要连接文库账号' : '文库分类加载失败',
                  message: _error!,
                  actionLabel: _needsLogin ? '登录 / 官网验证' : '重试',
                  onRetry: _needsLogin && widget.account != null
                      ? _loginForLibrary
                      : _load,
                )
              : const LibrarySkeleton())
        : AnimatedBuilder(
            animation: _feed!,
            builder: (context, _) => _catalogBody(context),
          ),
  );
}
