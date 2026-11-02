# 日轻：自定义书源配置

日轻默认保留轻小说文库（https://www.wenku8.net/）作为主站。自定义书源不会替换主站登录、首页或默认发现页；启用后，搜索结果会与主站结果合并，并显示各自的来源标签。

## 添加书源

1. 打开 **我的 → 设置 → 书源管理 → 添加自定义书源**。
2. 填写网站名称、HTTPS 根地址和搜索地址模板。
3. 配置搜索结果、目录和正文的 CSS 选择器。
4. 点 **测试搜索**，确认能够解析到结果后保存。
5. 在书源列表打开 **参与搜索** 开关。

新建书源默认停用，避免未测试的网站自动收到搜索请求。

## 地址模板

- \`{keyword}\`：搜索关键词，应用会进行 UTF-8 URL 编码。
- \`{page}\`：搜索页码。
- \`{field}\`：\`title\` 或 \`author\`，可选。
- \`{bookUrl}\`：书籍详情页的完整地址，可用于目录地址模板。

## CSS 选择器示例

| 用途 | 示例 |
|---|---|
| 搜索结果容器 | \`.book-item\` |
| 搜索结果标题 | \`.book-title a\` |
| 搜索结果作者 | \`.author\` |
| 搜索结果分类 | \`.tags\` |
| 搜索下一页 | \`a.next\` |
| 详情页书名 | \`h1.book-title\` |
| 目录章节条目 | \`#chapter-list a\` |
| 目录下一页 | \`a.next\` |
| 正文容器 | \`#content\` |

选择器只是常见写法示例，不代表所有网站都采用相同结构。需要按目标网站的实际 HTML 调整。

## JSON 配置示例

可以在书源卡片中复制 JSON，在另一台设备或重新安装后通过 **从剪贴板导入书源 JSON** 恢复。

\`\`\`json
{
  "id": "source-example",
  "name": "示例轻小说站",
  "baseUrl": "https://example.com/",
  "enabled": false,
  "loginUrl": "/login",
  "searchUrlTemplate": "https://example.com/search?q={keyword}&page={page}&type={field}",
  "searchItemSelector": ".book-item",
  "searchTitleSelector": ".book-title a",
  "searchLinkSelector": "",
  "searchNextPageSelector": "a.next",
  "searchAuthorSelector": ".author",
  "searchGenreSelector": ".tags",
  "searchSummarySelector": ".intro",
  "searchCoverSelector": "img.cover",
  "searchCoverAttribute": "data-src",
  "detailTitleSelector": "h1.book-title",
  "detailAuthorSelector": ".book-author",
  "detailSummarySelector": ".book-intro",
  "detailGenreSelector": ".book-tags",
  "detailStatusSelector": ".book-status",
  "detailCoverSelector": ".book-cover img",
  "detailCoverAttribute": "src",
  "chapterListUrlTemplate": "",
  "chapterItemSelector": "#chapter-list a",
  "chapterTitleSelector": "",
  "chapterHrefSelector": "a[href]",
  "chapterNextPageSelector": "a.next",
  "chapterContentSelector": "#content",
  "imageHosts": ["cdn.example.com"]
}
\`\`\`

以上域名和 CSS 规则仅为模板，不能直接用于真实网站。

## 登录与网络边界

- 轻小说文库仍是日轻的默认主站账号。
- 自定义书源可填写同域名的登录页面；登录会在独立 WebView 中完成，Cookie 按网站域名隔离，不会把其他网站的密码交给文库主站。
- 网页抓取要求 HTTPS，普通页面、搜索结果、详情、目录和正文请求限制在配置的主域名；图片可额外指定最多 12 个 CDN 域名。
- 当前通用书源抓取与独立登录首版仅接入 Android，适用于静态 HTML 和 GET 搜索。依赖复杂 JavaScript 渲染、POST 接口、跨域登录跳转、验证码或动态 API 的网站，需要针对该网站额外适配。
- 目录支持配置下一页选择器，最多自动读取 20 页、5000 个章节；搜索可配置下一页选择器。
