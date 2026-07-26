# Roadmap

> 2026-07-26 改版:对齐伴生渲染窗方向(`TECH-PLAN.md`);Phase 1 从"填 open_path 逻辑"改为"探针先行"。  
> 2026-07-26 晚:Phase 4 开源发布。

## Phase 0 — 架构骨架 ✅(2026-07-26 上午)

- [x] 仓库与 marketplace 目录
- [x] plugin.json / commands / skill / scripts stub
- [x] ARCHITECTURE + README + COMPETITIVE

## Phase 1 — 探针(开发第一件事,48h 可证伪;没跑完不写渲染窗) ✅(2026-07-26)

- [x] P1:Grok TUI 是否透传并渲染 hook 输出中的 OSC-8 可点击链接 → **不通**（详见 `TECH-PLAN.md` §8）
- [x] P2:hook 在 md 写入后能否同步拿到文件路径(事件 payload) → **通**（`toolInput.file_path`）
- [x] 结论+证据追加到 `TECH-PLAN.md` §8,据此锁定点击链路方案（主路径=`/open`/`/preview`；hook 侧信道）

## Phase 2 — 渲染窗 MVP ✅(2026-07-26)

- [x] 轻量常驻渲染窗:传入路径 → 浏览器级渲染(表格/代码高亮/图片) · `viewer/` Swift+WKWebView · 离线 marked/hljs
- [x] 注册自定义 URL scheme `md-reader://` · `build_app.sh --install` → `~/Applications/MdReader.app`
- [x] `/open` `/preview` 打通渲染窗;`open_path.py` 完整(路径解析/`--dry-run`/错误码/app 覆盖)
- [x] 本机 symlink 到 `~/.grok/plugins/md-reader` 验收 · `grok inspect` 见 md-reader (user, enabled)

## Phase 3 — 送达闭环 ✅(2026-07-26，工单三件；工作区边界后置)

- [x] hook:md 写入后侧信道写 last_path / 会话文件列表(Phase 1:不做 OSC-8 可见行;可关)
  - `hooks/on_md_write.py` + 可靠安装：`scripts/install_sidechannel_hook.sh` → `~/.grok/hooks/`
  - 数据目录：`~/.grok/plugin-data/user/md-reader/`（`last_path` · `history/current.json`）
  - 关闭：`touch …/hook_disabled` 或 `MD_READER_HOOK_DISABLE=1`
- [x] 渲染窗热刷新:DispatchSource 监听当前文件；删除/移动优雅降级不崩窗
- [x] 渲染窗历史列表:读侧信道 `history/current.json`，工具栏 History 可切换；`/preview` → last_path
- [ ] 工作区边界:默认禁止打开 workspace 外(可配置)（**后置**）

## Phase 4 — 打磨与开源发布 ✅(2026-07-26)

- [x] README(英文面向社区)+ 中文 `README.zh-CN.md` + demo GIF（`docs/assets/demo.gif`）
- [x] 一条命令安装路径：`./install.sh`
- [ ] mermaid 等增强渲染（**视情况，未做**；marked/hljs 已覆盖表格与代码高亮）

## 后置(本期不做)

- 跨 CLI 兼容:抽"viewer + 薄 adapter"架构,先做 Claude Code adapter(背景见 COMPETITIVE.md)
- 工作区边界强制
- mermaid / 数学公式等增强渲染

## 非目标

- 改 Grok TUI 内核 / 等官方内置面板
- 终端内字符渲染(glow 式)
- 自研 Markdown 渲染引擎(渲染窗用现成库)
