---
description: Re-open the last file opened or written via md-reader
---

# /preview

Re-open the last path recorded by md-reader (`$GROK_PLUGIN_DATA/last_path` or helper default).

## Steps

1. Run:

```bash
python3 "${GROK_PLUGIN_ROOT:-.}/skills/open-md/scripts/open_path.py" --preview
```

2. If helper says no last path, tell the user to `/open <path>` first or name a file.
3. Do not invent a previous path.
