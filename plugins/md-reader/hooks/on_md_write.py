#!/usr/bin/env python3
"""PostToolUse side-channel: record last_path + session md list (no visible output).

Disable: MD_READER_HOOK_DISABLE=1|true|yes  OR  touch $data_dir/hook_disabled
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

MD_EXTS = {".md", ".markdown", ".mdc", ".mdx"}
MAX_HISTORY = 50


def data_dir() -> Path:
    """Writable store: env first, else ~/.grok/plugin-data/*/md-reader, else config fallback."""
    for key in ("GROK_PLUGIN_DATA", "CLAUDE_PLUGIN_DATA"):
        env = os.environ.get(key)
        if env:
            p = Path(env).expanduser().resolve()
            p.mkdir(parents=True, exist_ok=True)
            return p

    base = Path.home() / ".grok" / "plugin-data"
    if base.is_dir():
        matches = sorted(base.glob("*/md-reader"), key=lambda p: p.stat().st_mtime, reverse=True)
        if matches:
            return matches[0]

    preferred = Path.home() / ".grok" / "plugin-data" / "user" / "md-reader"
    preferred.mkdir(parents=True, exist_ok=True)
    return preferred


def hook_disabled(d: Path | None = None) -> bool:
    if os.environ.get("MD_READER_HOOK_DISABLE", "").strip().lower() in ("1", "true", "yes"):
        return True
    root = d or data_dir()
    flag = root / "hook_disabled"
    if not flag.is_file():
        return False
    try:
        text = flag.read_text(encoding="utf-8").strip().lower()
    except OSError:
        return True
    # empty file or 1/true/yes/on → disabled; 0/false/no/off → enabled
    if text in ("", "1", "true", "yes", "on"):
        return True
    if text in ("0", "false", "no", "off"):
        return False
    return True


def extract_path(payload: dict) -> str | None:
    tin = payload.get("toolInput") or {}
    if isinstance(tin, dict):
        for key in ("file_path", "target_file", "path"):
            v = tin.get(key)
            if isinstance(v, str) and v.strip():
                return v.strip()
    tr = payload.get("toolResult")
    if isinstance(tr, dict):
        edits = tr.get("EditsApplied") or tr.get("editsApplied") or {}
        if isinstance(edits, dict):
            ap = edits.get("absolute_path") or edits.get("absolutePath")
            if isinstance(ap, str) and ap.strip():
                return ap.strip()
    return None


def is_markdown(path: str) -> bool:
    return Path(path).suffix.lower() in MD_EXTS


def normalize_path(path: str, cwd: str | None) -> str:
    try:
        p = Path(path).expanduser()
        if not p.is_absolute():
            p = (Path(cwd or os.getcwd()) / p).resolve()
        else:
            p = p.resolve()
        return str(p)
    except OSError:
        return path


def record_write(path_s: str, session_id: str | None, d: Path | None = None) -> dict:
    """Write last_path + session history. Returns paths written (for tests)."""
    root = d or data_dir()
    root.mkdir(parents=True, exist_ok=True)
    last = root / "last_path"
    last.write_text(path_s, encoding="utf-8")

    sid = (session_id or "default").replace("/", "_")[:120]
    hist_dir = root / "history"
    hist_dir.mkdir(parents=True, exist_ok=True)
    jsonl = hist_dir / f"{sid}.jsonl"

    # load existing unique order for this session
    paths: list[str] = []
    if jsonl.is_file():
        try:
            for line in jsonl.read_text(encoding="utf-8").splitlines():
                if not line.strip():
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                p = obj.get("path")
                if isinstance(p, str) and p and p not in paths:
                    paths.append(p)
        except OSError:
            paths = []

    if path_s in paths:
        paths.remove(path_s)
    paths.append(path_s)
    paths = paths[-MAX_HISTORY:]

    try:
        with jsonl.open("w", encoding="utf-8") as f:
            for p in paths:
                f.write(json.dumps({"path": p}, ensure_ascii=False) + "\n")
    except OSError:
        pass

    current = {
        "sessionId": session_id or "default",
        "paths": paths,
    }
    current_path = root / "history" / "current.json"
    try:
        current_path.write_text(
            json.dumps(current, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except OSError:
        pass

    return {
        "data_dir": str(root),
        "last_path": str(last),
        "current": str(current_path),
        "paths": paths,
    }


def process_payload(payload: dict, d: Path | None = None) -> dict | None:
    """Pure-ish entry for tests. Returns record result or None if skipped."""
    root = d or data_dir()
    if hook_disabled(root):
        return None

    tool = payload.get("toolName") or ""
    if tool not in ("write", "search_replace"):
        return None

    path = extract_path(payload)
    if not path or not is_markdown(path):
        return None

    path_s = normalize_path(path, payload.get("cwd"))
    return record_write(path_s, payload.get("sessionId"), root)


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return 0
    process_payload(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
