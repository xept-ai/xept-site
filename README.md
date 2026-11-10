# xept-site

[xept.online](https://xept.online) 的落地页。纯静态，没有依赖，没有构建步骤。

## 目录

| 路径 | 是什么 |
|---|---|
| `site/` | **线上内容**。Cloudflare Pages 服务的就是这个目录，由脚本生成，不要手改 |
| `src/index.html` | **页面源文件**，改文案改这里 |
| `src/assets/` | 20 张文档截图，都是 Xept 真实写出来的文件 |
| `src/fonts/` | 自己托管的 Inter / Noto Sans SC / IBM Plex Mono 子集，共 170KB |
| `src/og.png` · `src/og.html` | 分享卡片图 1200×630 和它的源文件 |
| `src/build-site.sh` | 把源文件包成完整 HTML 文档，连同资源输出到 `site/` |
| `src/build-fonts.sh` | 重新生成字体子集 |

`src/index.html` 没有 `<!doctype>`、`<html>`、`<head>`、`<body>`——它同时也是 claude.ai 上那个预览版的源文件，那边的平台会自己补这些标签。`build-site.sh` 负责给线上版补上，外加 charset、viewport、Open Graph、favicon 这些只有真实站点才需要的东西。

## 改页面

```sh
cd src
# 1. 改 index.html
# 2. 如果动了文案（出现了新的汉字），重新生成字体子集：
./build-fonts.sh
# 3. 重新生成线上内容：
./build-site.sh
# 4. 提交推送，Cloudflare Pages 自动部署
```

字体子集**只包含页面当前用到的字**。改了文案不跑 `build-fonts.sh`，新字会悄悄掉成系统字体。

## 发新版本要改的地方

下载按钮写死的是 v0.4.1 的资产链接。发版后要改 `src/index.html` 里的三处 URL 和 `.ver` 里的版本号：

- `Xept-0.4.1-mac-arm64.dmg`
- `Xept-0.4.1-win-x64-setup.exe`
- `Xept-0.4.1-linux-x86_64.AppImage`

安装包在 [xept-ai/xept-desktop-releases](https://github.com/xept-ai/xept-desktop-releases/releases) 的 Releases 里。

## 部署

Cloudflare Pages → 连接这个仓库 → 构建命令留空 → **构建输出目录填 `site`** → 自定义域绑 `xept.online`。
