#!/usr/bin/env python3
"""Map file extension → reader app key (used by diagnostics; open_path has the real logic)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def plugin_root() -> Path:
    env = os.environ.get("GROK_PLUGIN_ROOT") or os.environ.get("CLAUDE_PLUGIN_ROOT")
    if env:
        return Path(env).expanduser().resolve()
    return Path(__file__).resolve().parents[1]


def data_dir() -> Path:
    env = os.environ.get("GROK_PLUGIN_DATA") or os.environ.get("CLAUDE_PLUGIN_DATA")
    if env:
        return Path(env).expanduser().resolve()
    return Path.home() / ".config" / "grok-md-reader"


def load_config() -> dict:
    for path in (data_dir() / "readers.json", plugin_root() / "config" / "readers.example.json"):
        if path.is_file():
            try:
                return json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
    return {"default": "system", "by_extension": {}}


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: resolve_reader.py <path>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    cfg = load_config()
    ext = path.suffix.lower()
    app = (cfg.get("by_extension") or {}).get(ext) or cfg.get("default") or "system"
    print(json.dumps({"path": str(path), "app": app, "extension": ext}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
