---
description: Open a local document (fallback when Cmd+click is unavailable)
argument-hint: <path>
---

# /open

**Fallback** when the path is not a Cmd+clickable tool-line `file://` link.

After `./install.sh`, the primary path is: **Cmd+click** a path on a Grok
tool line → system open → OS defaults (`.md` → MdReader, `.pdf` → Preview, …).

Use `/open` for plain chat text paths, Terminal.app without OSC-8, or when
the user asks you to open a file.

Helper routing (same policy as install defaults):

- **Markdown / text** → MdReader
- **PDF** → Preview
- **Word / PPT / Excel** → installed Office apps; else system default
- **Unknown** → system `open`

## Arguments

- `$ARGUMENTS` — relative or absolute path to a local file

## Steps

1. If `$ARGUMENTS` is empty, ask the user for a path (do not guess).
2. Resolve the path relative to the session working directory when not absolute.
3. Run the helper (prefer plugin root env when present):

```bash
python3 "${GROK_PLUGIN_ROOT}/skills/open-md/scripts/open_path.py" -- "$ARGUMENTS"
```

If `GROK_PLUGIN_ROOT` is unset (dev mode), from the plugin package root:

```bash
python3 skills/open-md/scripts/open_path.py -- <path>
```

4. Report success (`opened (…): …`) or the helper's error. Do not invent paths.
5. On success the helper records the path for `/preview`.

## Notes

- Never open remote URLs.
- Never execute file content.
- Mapping: `config/readers.example.json` or `$GROK_PLUGIN_DATA/readers.json`.
- OS defaults broken? `./install.sh --set-defaults` or `./install.sh --doctor`.
- Viewer missing? `./viewer/scripts/build_app.sh --install`
