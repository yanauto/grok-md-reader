"""Side-channel hook unit tests (no Grok process)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

HOOK = (
    Path(__file__).resolve().parents[1]
    / "plugins"
    / "md-reader"
    / "hooks"
    / "on_md_write.py"
)

# Import module by path
sys.path.insert(0, str(HOOK.parent))
import on_md_write as hook  # noqa: E402


def payload_write(path: str, session: str = "sess-1", cwd: str | None = None) -> dict:
    return {
        "hookEventName": "post_tool_use",
        "sessionId": session,
        "cwd": cwd or "/tmp",
        "toolName": "write",
        "toolInput": {"file_path": path, "content": "# hi\n"},
        "toolResult": {},
    }


def test_records_last_path_and_current_list(tmp_path: Path):
    md = tmp_path / "a.md"
    md.write_text("# a\n", encoding="utf-8")
    r = hook.process_payload(payload_write(str(md), "abc"), d=tmp_path)
    assert r is not None
    assert (tmp_path / "last_path").read_text(encoding="utf-8").strip() == str(md.resolve())
    cur = json.loads((tmp_path / "history" / "current.json").read_text(encoding="utf-8"))
    assert cur["sessionId"] == "abc"
    assert cur["paths"] == [str(md.resolve())]


def test_session_list_accumulates_unique(tmp_path: Path):
    a = tmp_path / "a.md"
    b = tmp_path / "b.md"
    a.write_text("a", encoding="utf-8")
    b.write_text("b", encoding="utf-8")
    hook.process_payload(payload_write(str(a), "s1"), d=tmp_path)
    hook.process_payload(payload_write(str(b), "s1"), d=tmp_path)
    hook.process_payload(payload_write(str(a), "s1"), d=tmp_path)  # move a to end
    cur = json.loads((tmp_path / "history" / "current.json").read_text(encoding="utf-8"))
    paths = cur["paths"]
    assert paths == [str(b.resolve()), str(a.resolve())]


def test_ignores_non_md(tmp_path: Path):
    py = tmp_path / "x.py"
    py.write_text("x", encoding="utf-8")
    r = hook.process_payload(payload_write(str(py)), d=tmp_path)
    assert r is None
    assert not (tmp_path / "last_path").exists()


def test_ignores_other_tools(tmp_path: Path):
    md = tmp_path / "a.md"
    md.write_text("a", encoding="utf-8")
    p = payload_write(str(md))
    p["toolName"] = "read_file"
    assert hook.process_payload(p, d=tmp_path) is None


def test_search_replace_records(tmp_path: Path):
    md = tmp_path / "doc.md"
    md.write_text("old", encoding="utf-8")
    p = {
        "sessionId": "s",
        "cwd": str(tmp_path),
        "toolName": "search_replace",
        "toolInput": {
            "file_path": str(md),
            "old_string": "old",
            "new_string": "new",
        },
    }
    r = hook.process_payload(p, d=tmp_path)
    assert r is not None
    assert "doc.md" in (tmp_path / "last_path").read_text()


def test_disable_via_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    md = tmp_path / "a.md"
    md.write_text("a", encoding="utf-8")
    monkeypatch.setenv("MD_READER_HOOK_DISABLE", "1")
    assert hook.process_payload(payload_write(str(md)), d=tmp_path) is None
    assert not (tmp_path / "last_path").exists()


def test_disable_via_flag_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("MD_READER_HOOK_DISABLE", raising=False)
    (tmp_path / "hook_disabled").write_text("1\n", encoding="utf-8")
    md = tmp_path / "a.md"
    md.write_text("a", encoding="utf-8")
    assert hook.process_payload(payload_write(str(md)), d=tmp_path) is None


def test_flag_file_false_enables(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("MD_READER_HOOK_DISABLE", raising=False)
    (tmp_path / "hook_disabled").write_text("0\n", encoding="utf-8")
    md = tmp_path / "a.md"
    md.write_text("a", encoding="utf-8")
    assert hook.process_payload(payload_write(str(md)), d=tmp_path) is not None
