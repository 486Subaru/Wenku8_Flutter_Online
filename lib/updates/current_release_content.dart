import 'release_notices.dart';

class ReleaseSection {
  const ReleaseSection(this.title, this.items);
  final String title;
  final List<String> items;
}

const releaseFreeNotice = '**本项目完全免费，无任何赞助、打赏或付费渠道。**';
const releaseReadingNotice =
    '**在线内容以各书源网站实际开放状态为准，不提供因版权或站点限制而停止开放的内容。**';
const releaseMaintenanceNotice =
    '日轻基于 Wenku8 0.5.5 的界面与本地阅读体验继续开发；本次重点不是重做阅读器，而是把已经移除或失效的联网能力重新建立，并整理成可继续扩展的多书源结构。';

const _why =
    '为什么要做这些改动：原来的联网逻辑建立在旧域名、旧接口、旧登录方式和旧页面结构上。到 2026 年，多个站点已经出现域名迁移、HTTPS 与 API 变化、Cookie／登录凭据变化、页面结构调整，以及不同网络环境下可达性不一致等问题。如果继续“遇到一个报错补一个白名单”，后续增加书源时同类问题还会反复出现，所以这次把目标从“恢复一个网站”扩大为“重新建立一套可维护的联网与多书源架构”。';
const _online =
    '恢复在线阅读链路：重新接入主页／书库、搜索、作品详情、目录、章节正文、封面和网站登录，并继续保留原有本地书籍、书架和阅读流程。这样做是为了让 0.5.5 原本很好用的本地阅读器重新具备直接找书和阅读的能力，而不是每次都要在外部手动查找、下载再导入。';
const _multiSource =
    '新增并整理多书源体系：书源可以独立启用、参与搜索、作为主页来源或只承担网页登录；不同站点的 Cookie 与请求域名按书源隔离。这样做是因为任何单一网站都可能维护、换域名、改接口或暂时不可达，不能让一个站点出问题就把整个 App 的联网功能一起拖死。';
const _loginHome =
    '登录网站与主页书源分离：登录身份和“主页从哪里取书”本来就是两件事。此前会出现已经登录 A 网站，主页却仍去请求 Wenku8 或默认源的情况，甚至把正常跳转误判为非法地址。现在登录、主页、搜索和阅读链路按能力分别管理；真正支持完整阅读的书源会保持主页、搜索、详情、目录和正文使用同一套来源。';
const _linovel =
    '轻之文库（Linovel）：从原先仅能打开网页登录页面，升级为真正的阅读书源，接入主页浏览、搜索、详情、目录、章节正文和登录状态，并提供旧配置兼容迁移。原因是“网页能登录”并不等于 App 能读书；以前登录成功后，App 仍缺少原生取书链路，所以会出现“登进去了但主页还是不能用”。';
const _lightNovel =
    '轻之国度：针对 2026 年新版站点重新适配公开读取与 BFF 搜索接口，去掉“必须先拿到旧 Token 才允许加载公开内容”的错误前置条件，并更新登录状态识别。原因是旧 Token／旧接口假设已经过时，不能让公开可读内容被一个失效的旧登录判断挡住。需要说明：如果当前网络本身无法到达 lightnovel.fun，仍需要具备能正常访问该站点的网络环境；这属于网络可达性，不是 App 能绕过的登录问题。';
const _wenku8 =
    'Wenku8：将当前官方链路迁移到 wenku8.net，同时兼容旧 wenku8.cc 链接、Cookie 和解析规则。这样做是因为官网正常换域名不应该再被 App 当成“跳转到非允许域名”，同时又不能为了省事把所有外部域名全部放开。';
const _bilinovel =
    '哔哩轻小说：补充 linovelib.com、bilinovel.com、bilinovel.net 之间的官方域名迁移链，避免正常官方跳转被旧白名单拦截。目前它仍主要作为网页登录入口，完整原生阅读适配与登录能力分开处理，避免把“能登录”误写成“已经完整支持阅读”。';
const _network =
    '网络结构重新整理：统一处理官方域名与 HTTPS 请求边界，按书源管理允许的请求／登录主机，并继续隔离不同站点的会话。这里不是简单“关闭安全限制”，而是改成“允许正确的官方站点正常工作，同时继续阻止无关地址”，减少以后网站正常迁移时反复出现相同故障。';
const _stability =
    '稳定性与维护：保留旧书源配置迁移逻辑，让升级后的用户尽量不丢失已经保存的来源和登录选择；同时把 v2284 构建期临时补丁正式落入真实源码，v2285 起常规构建不再每次重新打同一批补丁。这样以后新增或修复书源时，可以直接在统一结构上维护，减少重复代码和补丁叠补丁。';
const _updateChannel =
    'v2286 修复应用内更新通道：日轻不再检查原版 mikufoxxx/Wenku8_Flutter 的 Release，也不再使用原版更新镜像；更新只认 486Subaru/Wenku8_Flutter_Online 自己的 GitHub Release。仓库或 Release 尚未公开时，匿名更新检查会表现为暂无可用更新，而不会再弹出原版更新提示。';
const _build =
    '应用名称为「日轻」，当前版本为 0.5.5 · 联网增强版 v2286。Android 使用独立 applicationId，与原版安装互不覆盖；本次构建面向 ARM64 Android 设备。';

const publicReleaseNotes = '''
# 日轻 0.5.5 联网增强版 · v2286

$releaseFreeNotice

$releaseReadingNotice

**$currentReleaseSourcePolicy**

## 这次为什么会改这么多
$_why

## 恢复联网，但保留原来的阅读体验
$_online

## 为什么要做多书源
$_multiSource

## 为什么登录网站和主页书源必须拆开
$_loginHome

## 轻之文库
$_linovel

## 轻之国度
$_lightNovel

## Wenku8
$_wenku8

## 哔哩轻小说
$_bilinovel

## 网络与安全结构
$_network

## 稳定性与后续维护
$_stability

## v2286 · 更新通道修复
$_updateChannel

## 应用与构建
$_build

$releaseMaintenanceNotice
''';

const currentReleaseNotes = publicReleaseNotes;
const currentReleaseSummary = [
  releaseFreeNotice,
  releaseReadingNotice,
  currentReleaseSourcePolicy,
  _why,
  _online,
  _multiSource,
  _loginHome,
  _linovel,
  _lightNovel,
  _wenku8,
  _bilinovel,
  _network,
  _stability,
  _updateChannel,
  _build,
];

const currentReleaseSections = [
  ReleaseSection('日轻 v2286 · 为什么这样改', [
    releaseFreeNotice,
    releaseReadingNotice,
    currentReleaseSourcePolicy,
    _why,
  ]),
  ReleaseSection('联网与多书源', [_online, _multiSource, _loginHome]),
  ReleaseSection('书源适配', [_linovel, _lightNovel, _wenku8, _bilinovel]),
  ReleaseSection('网络、稳定性与构建', [
    _network,
    _stability,
    _updateChannel,
    _build,
    releaseMaintenanceNotice,
  ]),
];
