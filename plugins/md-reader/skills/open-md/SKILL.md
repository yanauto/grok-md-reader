---
name: open-md
description: >
  Fallback opener when the user cannot Cmd+click a tool-line path (plain chat
  text, Terminal.app, or they ask you to open). Markdown → MdReader; PDF/Office
  → system apps per readers.json. Prefer telling users to Cmd+click tool-line
  file:// links after install. Triggers: /open /preview, 打开md、打开pdf、
  open this file, preview the file.
---

# open-md

## Goal

**Primary product path (no agent needed):** after `./install.sh`, user
**Cmd+clicks** a path on a Grok **tool line** (`file://` link) → system open →
OS defaults set at install (`.md` → MdReader, `.pdf` → Preview, …).

**This skill is a fallback** when:

- Path is plain chat text (not a hyperlink)
- Terminal ignores OSC-8 (e.g. some Terminal.app setups)
- User explicitly asks you to open / preview

| 类型 | 默认打开方式 |
|------|----------------|
| `.md` / `.markdown` / `.txt` | MdReader 伴生窗 |
| `.pdf` | Preview |
| `.doc` / `.docx` | Microsoft Word（失败 → 系统默认） |
| 其它映射类型 | `readers.json` / example 配置 |
| 未知扩展名 | 系统 `open` / `xdg-open` |

## When to use

- User says open / preview / 打开 / 预览 a path
- Path was only printed as plain text (not on a tool line)
- User reports Cmd+click did nothing

## When not to use

- User can already Cmd+click a tool-line path (install defaults handle it)
- User wants to **edit** content
- Remote URL or non-file resource

## Procedure

1. Determine the path (user-supplied or the file you just wrote this turn).
2. Call the helper:

```bash
python3 "${GROK_PLUGIN_ROOT}/skills/open-md/scripts/open_path.py" -- "/absolute/or/relative/path"
```

3. Surface the helper stdout/stderr. On success, one line is enough.
4. If path missing, ask once — do not search the whole disk.
5. `/preview` 无参时用 `--preview`（读 last_path）。

## Safety

- Local files only
- No network
- Do not `cat` huge files into chat just to "open" them — prefer the mapped reader
