---
description: Open a local file (usually .md) in the MdReader companion window
argument-hint: <path>
---

# /open

Open the given local path with the **md-reader** helper（默认唤起 MdReader 伴生渲染窗）。

## Arguments

- `$ARGUMENTS` — relative or absolute path to a file (prefer `.md` / `.markdown` / `.txt`)

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

4. Report success (`opened (md-reader): …`) or the helper's error. Do not invent paths.
5. On success the helper records the path for `/preview`.

## Notes

- Never open remote URLs.
- Never execute the markdown content.
- Viewer missing? hint user: `./viewer/scripts/build_app.sh --install`
