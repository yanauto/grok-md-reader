# grok-md-reader

Grok CLI 的 macOS Markdown 伴生阅读器。Agent 写完 `.md`，旁边原生窗口直接给出完整渲染——表格、代码高亮，一次到位。

[English README](README.md)

![演示：从 Grok CLI 打开 md 到 MdReader](docs/assets/demo.gif)

---

## 为什么做

我大部分时间在终端里跑编码 Agent，它们不断产出 markdown：报告、计划、调研笔记。终端里这些全是 raw 文本。每次真想读一遍，都得去 Finder 或编辑器里翻，几周下来就烦了。

Claude Desktop 做得好：会话里递文件，点一下，侧栏渲染。我想给 Grok CLI 同样的闭环，于是做成了「插件 + 小渲染窗」。

## 你得到什么

- **MdReader.app** — 原生小窗口（Swift + WKWebView），内嵌 marked 与 highlight.js。离线渲染，内容不出本机。
- **Grok 插件** — `/open <path>`、`/preview`，以及 skill，让 agent 在你开口时自己帮你打开文件。
- **自动追踪** — `PostToolUse` hook 记录本会话 agent 写过的每个 markdown。`/preview` 打开最近一个；渲染窗 History 在列表间切换。
- **热刷新** — 文件打开后持续监听；agent 继续改，窗口自己重渲染。文件消失时优雅降级，不崩窗。
- **点击打开** — Grok 工具行带 `file://` 超链接。把 `.md` 默认应用设为 MdReader 后，Cmd+点击写入路径即可渲染打开。

## 安装

需要：macOS、Grok CLI、Python 3、Xcode Command Line Tools（`swiftc`）。

```bash
git clone https://github.com/yan-auto/grok-md-reader.git
cd grok-md-reader
./install.sh
```

一条脚本完成：**构建 MdReader.app**、链接 Grok 插件、安装追踪 hook。分步命令见 [`install.sh`](install.sh)。

验收：

```bash
grok inspect        # Plugins → md-reader
python3 plugins/md-reader/skills/open-md/scripts/open_path.py README.md
# 应弹出 MdReader 窗口

# 新会话里让 agent 写过 .md 后：
cat ~/.grok/plugin-data/user/md-reader/last_path
```

## 点击打开（可选，推荐）

Grok TUI 已在 Write/Edit 工具行发出 `file://` 超链接。要让点击进 MdReader：

1. Finder 选中任意 `.md`，按 ⌘I。
2. 「打开方式」选 **MdReader** → 「全部更改…」。

之后在会话里 Cmd+点击写入路径即可打开渲染文档。安装脚本**不会**改系统默认应用，这一步刻意留给你手动确认。

依赖终端对 OSC-8 的支持：iTerm2、Ghostty 一般可用 Cmd+click；系统自带 Terminal.app 会忽略这些链接——此时用 `/open` / `/preview` 即可。

## 关闭追踪 hook

```bash
touch ~/.grok/plugin-data/user/md-reader/hook_disabled   # 关
rm    ~/.grok/plugin-data/user/md-reader/hook_disabled   # 开
# 或环境变量 MD_READER_HOOK_DISABLE=1
```

hook 只写两个本地小文件（`last_path` 与会话历史列表），会话里没有可见输出。

## 换用其他阅读器

`config/readers.example.json` 按扩展名映射 App。复制到 `$GROK_PLUGIN_DATA/readers.json`，把 `.md` 指到 `system`、`typora`、`vscode` 等。默认仍是 MdReader。

## 设计说明

渲染窗与插件刻意拆开：经 `md-reader://` URL scheme 通信，两侧可独立替换升级。hook 保持静默——Grok 会忽略被动 hook 的 stdout（已对 grok-build 源码核实）。完整设计过程在 [`docs/`](docs/)（中文）：探针实验、源码结论、各阶段取舍。

## 限制

- 渲染窗目前仅 macOS。Linux 上插件仍可用，通过 `readers.json` 映射到 `xdg-open` 或任意编辑器。
- 聊天正文里任意文件名的点击不在范围内；超链接在工具行上。
- 工作区边界（拒绝打开项目外路径）在路线图中。

## 使用

| 命令 | 作用 |
|------|------|
| `/open <路径>` | 在 MdReader 中打开指定文件 |
| `/preview` | 重开上次打开/写入的文件 |

也可以自然语言：「打开 README.md」「预览你刚写的 md」。

## License

MIT
