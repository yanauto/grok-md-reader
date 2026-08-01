# ADR-0002: 即装即用 = 安装器写入 OS 默认 App（Cmd+点击走系统 open）

**日期**：2026-07-26（UTC+8）  
**状态**：Accepted

## 背景（Context）

用户与开源目标要求：

1. **即装即用**——不依赖 Agent 遵守 skill  
2. **CLI 上可点文件 Cmd+点击即可打开**

Grok 工具行路径已是 OSC-8 `file://`，点击走 **Grok 内置 opener → 系统 `open`**，插件**无法劫持**该点击。聊天正文裸路径通常**不是**超链接。  
旧主线（skill / `open_path.py` 为「点击正统」）无法满足开源装即用。

## 决策（Decision）

1. **产品主路径**：`./install.sh` 根据 `readers.json` / `readers.example.json` **写入 macOS Launch Services 默认处理程序**（`.md`→MdReader、`.pdf`→Preview、Office→对应 App 若已装）。  
2. **Cmd+点击** = 系统 `open` → 上述默认 App。与 `open_path.py` **策略同源**（同一映射表），进程不必经过 Python。  
3. **`/open` / skill / `open_path.py`** = **兜底**（裸文本路径、无 OSC-8 终端、脚本调用）。  
4. **不承诺**聊天气泡内裸路径可点（TUI 限制，写入 README）。  
5. install 提供 `--no-set-defaults` / `--set-defaults` / `--doctor`；默认**会**改默认 App。

## 理由（Rationale）

- 在不 fork Grok 的前提下，唯一能同时满足「装即用 + 一点就开」的是 **站在 OS 端接住 `open`**。  
- Agent 纪律不能当开源默认契约。  
- 映射表单一来源避免「命令一套、点击另一套」。

## 影响（Consequences）

- install 有轻微系统侵入（改默认 App）；可用 `--no-set-defaults` 关闭。  
- `.txt`/`.html` 不进 OS 默认（过宽）；仍可由 `/open` 走 md-reader。  
- 文档与 skill 叙事从「主靠 Agent 打开」改为「主靠安装默认 + 点击」。

## 相关

- 实现：`plugins/md-reader/scripts/apply_os_defaults.py`、`ls_default_handler.swift`、`install.sh`  
- 前序：ADR-0001 文档打开路由器（映射表语义保留，点击总线改为 OS）
