# ADR-0001: 文档打开路由器（系统 App，不自研阅读器）

**日期**：2026-07-26（UTC+8）
**状态**：Accepted

## 背景（Context）

产品从「只打开 Markdown」扩展到「识别多种可读文件并打开」。可选路径包括：为 PDF/Word 自研伴生窗，或按扩展名把文件交给本机已安装的系统/第三方阅读器。

目标是 agent 产出文档后用户能一步打开阅读，而不是在本插件内复刻 Office/PDF 引擎。

## 决策（Decision）

我们决定做 **「文档打开路由器」**：

- 按文件扩展名查 `readers.json` / `readers.example.json` 的 `by_extension` → app key
- **`.md` / `.markdown` / `.txt` 等** → 自家 MdReader 伴生窗（`md-reader://`）
- **`.pdf`** → 本机 Preview（可配置）
- **`.doc` / `.docx`** → Microsoft Word（可配置）；失败回落系统默认 `open`
- **其它 Office / 未知类型** → 映射表或 `default: system`（`open` / `xdg-open`）
- **不自研** PDF / Word / PPT 渲染窗

产品命名 **暂时仍为 md-reader**（本 ADR 不锁定改名时机，仅锁定打开形态）。

## 理由（Rationale）

- **自研 PDF/Word 窗**：工程量大、渲染质量难及系统 App，与「伴生送达」目标不匹配
- **只做 md、其它靠用户自己找文件**：体验回退，违背「文档送达」方向
- **扩展名路由 + 系统 App（采纳）**：骨架已在 `open_path.py` / `readers.example.json`；工作量主要是映射与回落；质量交给 OS 默认阅读器

## 影响（Consequences）

### 短期

- `/open` 与 skill 可打开 pdf/office；hook 侧信道可记录常见文档类型进 `last_path` / history
- MdReader History 点到非 md 时 handoff 给系统 App，不在 WKWebView 内硬渲染

### 长期

- 产品能力面从「md 阅读器」升为「可读文档打开器」；改名可后置
- 映射表是扩展点：用户可改 `$GROK_PLUGIN_DATA/readers.json` 换默认 App

### 潜在风险

- 本机未装 Word 时依赖回落与 OS 文件关联，体验因环境而异
- History 列表与 `readers.json` 映射不完全一致（系统默认 vs 配置的 Preview/Word）——可接受，后续可对齐

## 相关

- 关联 feature：多类型打开路由（`open_path.py` · `readers.example.json` · `on_md_write.py` TRACKED_EXTS）
- 实现入口：`plugins/md-reader/skills/open-md/scripts/open_path.py`
- 相关 ADR：无
