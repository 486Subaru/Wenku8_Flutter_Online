from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, found {count}: {old!r}')
    target.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) App update identity: Riqing checks only its own GitHub repository.
replace_once(
    'lib/updates/app_updates.dart',
    "const officialUpdateRepository = 'mikufoxxx/Wenku8_Flutter';",
    "const officialUpdateRepository = '486Subaru/Wenku8_Flutter_Online';",
)
replace_once(
    'lib/updates/app_updates.dart',
    "const updateRepository = String.fromEnvironment(\n  'UPDATE_REPOSITORY',\n  defaultValue: officialUpdateRepository,\n);",
    'const updateRepository = officialUpdateRepository;',
)
replace_once(
    'lib/updates/app_updates.dart',
    'const currentAppBuild = 2285;',
    'const currentAppBuild = 2286;',
)
replace_once(
    'lib/updates/app_updates.dart',
    "!name.startsWith('wenku8-${version.name}-')",
    "!name.startsWith('riqing-${version.name}-')",
)
replace_once(
    'lib/updates/app_updates.dart',
    "request.headers.set(HttpHeaders.userAgentHeader, 'Wenku8-Flutter');",
    "request.headers.set(HttpHeaders.userAgentHeader, 'Riqing-Android');",
)
replace_once(
    'lib/updates/app_updates.dart',
    'bool get _usesMirror => updateRepository == officialUpdateRepository;',
    'bool get _usesMirror => false;',
)

# 2) Build/version metadata.
replace_once('pubspec.yaml', 'version: 0.5.5+2285', 'version: 0.5.5+2286')

# 3) Release announcement keeps the v2285 history but adds the v2286 update-channel fix.
release = Path('lib/updates/current_release_content.dart')
text = release.read_text(encoding='utf-8')
text = text.replace(
    "const _build =\n    '应用名称改为「日轻」，当前版本为 0.5.5 · 联网增强版 v2285。Android 使用独立 applicationId，与原版安装互不覆盖；本次构建面向 ARM64 Android 设备。';",
    "const _updateChannel =\n    'v2286 修复应用内更新通道：日轻不再检查原版 mikufoxxx/Wenku8_Flutter 的 Release，也不再使用原版更新镜像；更新只认 486Subaru/Wenku8_Flutter_Online 自己的 GitHub Release。仓库或 Release 尚未公开时，匿名更新检查会表现为暂无可用更新，而不会再弹出原版更新提示。';\nconst _build =\n    '应用名称为「日轻」，当前版本为 0.5.5 · 联网增强版 v2286。Android 使用独立 applicationId，与原版安装互不覆盖；本次构建面向 ARM64 Android 设备。';",
    1,
)
text = text.replace('# 日轻 0.5.5 联网增强版 · v2285', '# 日轻 0.5.5 联网增强版 · v2286', 1)
text = text.replace(
    '## 应用与构建\n$_build',
    '## v2286 · 更新通道修复\n$_updateChannel\n\n## 应用与构建\n$_build',
    1,
)
text = text.replace('  _stability,\n  _build,', '  _stability,\n  _updateChannel,\n  _build,', 1)
text = text.replace("ReleaseSection('日轻 v2285 · 为什么这样改'", "ReleaseSection('日轻 v2286 · 为什么这样改'", 1)
text = text.replace('    _stability,\n    _build,', '    _stability,\n    _updateChannel,\n    _build,', 1)
if '_updateChannel' not in text or 'v2286' not in text:
    raise SystemExit('release notes migration failed')
release.write_text(text, encoding='utf-8')

# 4) Replace stale upstream README files with accurate fork documentation.
Path('README_ZH.md').write_text('''# 日轻（Riqing）\n\n> 非官方开源派生项目。基于 **MewX** 的 Wenku8 项目继续维护与扩展。\n\n**当前 Android 版本：0.5.5+2286（ARM64）**\n\n## 项目说明\n\n「日轻」保留 Wenku8 0.5.5 的阅读界面、本地书库与阅读体验，并恢复、整理已经失效或移除的联网能力。当前分支重点包括：\n\n- 在线主页、搜索、详情、目录与章节正文；\n- 多书源管理与自定义书源；\n- 登录网站与主页书源分离；\n- 不同书源 Cookie / 登录状态隔离；\n- Wenku8 新旧域名兼容；\n- 轻之文库、轻之国度等站点的现行接口适配；\n- 单书源异常隔离、缓存和网络稳定性优化。\n\n第三方网站随时可能修改域名、接口、登录方式或页面结构，因此不保证所有书源永久可用。\n\n## 更新通道\n\n从 **v2286** 起，应用内更新只检查本项目自己的 GitHub Release：\n\n`486Subaru/Wenku8_Flutter_Online`\n\n不再检查原版 `mikufoxxx/Wenku8_Flutter`，也不再使用原版更新镜像，因此不会再把原版更新误提示成「日轻」更新。\n\nGitHub Release 的 Android ARM64 安装包应命名为：\n\n`riqing-0.5.5-arm64-v8a.apk`\n\nRelease 标签应包含版本与 build，例如：`v0.5.5+2286`。\n\n> 当前仓库若仍为 Private，匿名应用内更新检查无法读取 Release；把仓库及对应 Release 公开后才会正常工作。\n\n## 安装\n\nAndroid 使用独立包名：\n\n`org.mewx.wenku8_flutter.online.fix`\n\n因此可以与原版并存，不需要卸载原版。\n\n## 上游、署名与许可证\n\n- 原项目 / 上游：`mikufoxxx/Wenku8`\n- 原作者：**MewX**\n- 本项目仓库：`486Subaru/Wenku8_Flutter_Online`\n- 源码许可证：**GNU GPL v2**，以仓库中的 `LICENSE` 为准。\n\n「日轻」是非官方派生维护项目，与 MewX、Wenku8 网站及其他第三方小说网站不存在官方隶属、代理或合作关系，除非相关权利方另有明确说明。\n\n本项目维护者发布的安装包不收费；GPL v2 本身允许在许可证条件下复制、修改和再分发，具体权利与义务以许可证正文为准。\n\n## 内容与第三方网站\n\n本项目不运营小说内容数据库。在线内容来自用户选择访问的第三方网站。小说、插画、封面、作品名称、商标及其他内容的权利归其各自权利人所有。请遵守所在地法律法规以及对应网站的服务条款。\n\n如相关权利人对某项适配、名称、图片或接口使用提出合理权利主张，经核实后可移除、停用或下架相关功能。\n\n## 构建\n\n项目使用 Flutter。常规 CI 会执行：\n\n- Dart 静态分析；\n- Flutter 自动化测试；\n- ARM64 Android Release 构建；\n- Android 原生单元测试。\n\n最终安装包以 GitHub Actions / Release 中明确标记的 ARM64 APK 为准。\n''', encoding='utf-8')

Path('README.md').write_text('''# Riqing (日轻)\n\n> An unofficial open-source derivative maintained on top of **MewX's Wenku8 project**.\n\n**Current Android version: 0.5.5+2286 (ARM64)**\n\n## What this fork does\n\nRiqing keeps the Wenku8 0.5.5 reading and local-library experience while restoring and reorganizing online reading into a maintainable multi-source architecture. It includes online discovery/search/detail/TOC/chapter flows, independent source sessions, custom sources, current Wenku8 domain compatibility, and adapters for additional supported sites.\n\nThird-party websites can change their domains, APIs, login systems, or page structures at any time, so permanent availability of every source cannot be guaranteed.\n\n## Update channel\n\nStarting with **v2286**, in-app updates check only this repository's GitHub Releases:\n\n`486Subaru/Wenku8_Flutter_Online`\n\nRiqing no longer checks `mikufoxxx/Wenku8_Flutter` and no longer uses its update mirror. This prevents upstream releases from being presented as Riqing updates.\n\nAndroid ARM64 release assets should be named:\n\n`riqing-0.5.5-arm64-v8a.apk`\n\nRelease tags should include the build number, for example `v0.5.5+2286`.\n\n> If this repository is still Private, anonymous in-app update checks cannot read its Releases. Make the repository and the intended Release public before relying on automatic updates.\n\n## Installation\n\nAndroid application ID:\n\n`org.mewx.wenku8_flutter.online.fix`\n\nIt can coexist with the original app.\n\n## Upstream, attribution and license\n\n- Upstream project: `mikufoxxx/Wenku8`\n- Original author: **MewX**\n- This repository: `486Subaru/Wenku8_Flutter_Online`\n- Source license: **GNU GPL v2**; see `LICENSE`.\n\nRiqing is an unofficial derivative and is not affiliated with MewX, the Wenku8 website, or any third-party novel website unless explicitly stated by the relevant rights holder.\n\nBuilds published by this project's maintainer are provided without charge. GPL v2 rights and obligations are governed by the license text itself.\n\n## Content and third-party services\n\nThis project does not operate a novel-content database. Online content is fetched from third-party services selected by the user. Novels, illustrations, covers, names, trademarks, and related materials remain the property of their respective rights holders. Users are responsible for complying with applicable law and each service's terms.\n\n## Build checks\n\nThe Flutter CI performs Dart analysis, Flutter tests, an ARM64 Android release build, and Android native unit tests.\n''', encoding='utf-8')

notice = Path('NOTICE')
notice_text = notice.read_text(encoding='utf-8')
old_notice_head = '''Wenku8 Flutter\n\nThe repository's existing LICENSE and assets/licenses/GPL-3.0.txt apply to\npublished source files. Third-party components retain their own copyrights\nand license conditions.\n'''
new_notice_head = '''Riqing (日轻)\n\nThis repository is an unofficial derivative of the Wenku8 project by MewX.\nUpstream: mikufoxxx/Wenku8\nDerivative repository: 486Subaru/Wenku8_Flutter_Online\n\nThe project source is distributed under GNU GPL version 2 as provided in\nLICENSE. This notice does not replace or weaken any upstream attribution,\nthird-party copyright notice, or third-party license condition.\n'''
if notice_text.count(old_notice_head) != 1:
    raise SystemExit('NOTICE header did not match expected upstream text')
notice.write_text(notice_text.replace(old_notice_head, new_notice_head, 1), encoding='utf-8')

# 5) Regression test: own repository + Riqing asset prefix are mandatory.
Path('test/app_updates_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/updates/app_updates.dart';

void main() {
  const repository = '486Subaru/Wenku8_Flutter_Online';
  const tag = 'v0.5.5+2287';

  Map<String, dynamic> releaseJson(String assetName) => {
    'tag_name': tag,
    'draft': false,
    'prerelease': false,
    'body': 'test',
    'assets': [
      {
        'id': 1,
        'name': assetName,
        'browser_download_url':
            'https://github.com/$repository/releases/download/$tag/$assetName',
        'size': 1024,
      },
    ],
  };

  test('Riqing update channel is pinned to the derivative repository', () {
    expect(updateRepository, repository);
    expect(currentAppBuild, 2286);
  });

  test('accepts Riqing ARM64 release assets', () {
    final release = AppRelease.fromGithub(
      releaseJson('riqing-0.5.5-arm64-v8a.apk'),
      repository,
    );
    expect(release, isNotNull);
    expect(release!.assets, hasLength(1));
    expect(release.assetFor(const ['arm64-v8a'])?.name,
        'riqing-0.5.5-arm64-v8a.apk');
  });

  test('rejects upstream Wenku8 package names', () {
    final release = AppRelease.fromGithub(
      releaseJson('wenku8-0.5.5-arm64-v8a.apk'),
      repository,
    );
    expect(release, isNotNull);
    expect(release!.assets, isEmpty);
  });
}
''', encoding='utf-8')

print('v2286 update-channel migration prepared')
