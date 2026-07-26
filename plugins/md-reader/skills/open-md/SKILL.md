---
name: open-md
description: >
  Open a local Markdown or text file in the MdReader companion window
  (browser-quality render) or a configured fallback app. Use when the user
  asks to open/preview/view an .md file, cannot read a file inside the CLI,
  or wants /open /preview. Triggers: 打开md、预览markdown、open this md,
  preview the file you just wrote.
---

# open-md

## Goal

Let the user **read** a local file outside the TUI, via the **MdReader 伴生渲染窗**
（默认）或 readers.json 配置的外部 App。

## When to use

- User says open / preview / 打开 / 预览 a `.md` (or text) path
- You just wrote a markdown file and user wants to read it
- User complains they cannot view md inside Grok CLI

## When not to use

- User wants you to **edit** content (use normal edit tools)
- Remote URL or non-file resource
- Binary formats (pdf/docx) unless user explicitly asks and helper supports later

## Procedure

1. Determine the path (user-supplied or the file you just wrote this turn).
2. Call the helper:

```bash
python3 "${GROK_PLUGIN_ROOT}/skills/open-md/scripts/open_path.py" -- "/absolute/or/relative/path.md"
```

3. Surface the helper stdout/stderr. On success, one line is enough.
4. If path missing, ask once — do not search the whole disk.
5. `/preview` 无参时用 `--preview`（读 last_path）。

## Safety

- Local files only
- No network
- Do not `cat` huge files into chat just to "open" them — prefer the companion viewer
