"""open_path.py unit/smoke tests (no GUI required — dry-run / validation only)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "plugins" / "md-reader" / "skills" / "open-md" / "scripts" / "open_path.py"
README = ROOT / "README.md"


def run(args: list[str], env: dict | None = None) -> subprocess.CompletedProcess[str]:
    full_env = os.environ.copy()
    if env:
        full_env.update(env)
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        env=full_env,
        cwd=str(ROOT),
    )


def test_script_exists():
    assert SCRIPT.is_file()


def test_refuses_http_url():
    r = run(["https://example.com/a.md"])
    assert r.returncode == 2
    assert "URL" in (r.stderr + r.stdout)


def test_refuses_file_url():
    r = run(["file:///tmp/x.md"])
    assert r.returncode == 2
    assert "URL" in (r.stderr + r.stdout)


def test_missing_path():
    r = run(["/tmp/md-reader-definitely-missing-xyz.md"])
    assert r.returncode == 1
    assert "not found" in (r.stderr + r.stdout).lower()


def test_usage_without_args():
    r = run([])
    assert r.returncode == 2


def test_dry_run_readme_default_mdreader():
    r = run(["--dry-run", str(README)])
    assert r.returncode == 0, r.stderr
    assert "DRY-RUN" in r.stdout
    assert "md-reader://open?" in r.stdout or "MdReader" in r.stdout or "open" in r.stdout


def test_dry_run_force_system():
    r = run(["--dry-run", "--app", "system", str(README)])
    assert r.returncode == 0
    assert "DRY-RUN" in r.stdout
    # system path should be plain `open <path>` style on darwin
    assert str(README) in r.stdout


def test_print_config(tmp_path):
    # Pin data dir empty so we load repo example, not a local $GROK_PLUGIN_DATA/readers.json
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--print-config"], env=env)
    assert r.returncode == 0
    data = json.loads(r.stdout)
    assert "default" in data
    assert data["default"] in ("md-reader", "system")
    by_ext = data.get("by_extension") or {}
    assert by_ext.get(".md") == "md-reader"
    assert by_ext.get(".pdf") == "preview"
    assert by_ext.get(".docx") == "word"


def test_dry_run_pdf_routes_to_preview(tmp_path):
    pdf = tmp_path / "sample.pdf"
    pdf.write_bytes(b"%PDF-1.4\n")
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path / "data"),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--dry-run", str(pdf)], env=env)
    assert r.returncode == 0, r.stderr
    out = r.stdout
    assert "DRY-RUN" in out
    assert "Preview" in out
    assert str(pdf) in out
    assert "md-reader://" not in out


def test_dry_run_docx_routes_to_word(tmp_path):
    docx = tmp_path / "note.docx"
    docx.write_bytes(b"PK\x03\x04")  # minimal zip-ish stub; open not invoked
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path / "data"),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--dry-run", str(docx)], env=env)
    assert r.returncode == 0, r.stderr
    assert "DRY-RUN" in r.stdout
    assert "Microsoft Word" in r.stdout
    assert "md-reader://" not in r.stdout


def test_dry_run_unknown_ext_routes_to_system(tmp_path):
    blob = tmp_path / "data.bin"
    blob.write_bytes(b"\x00\x01")
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path / "data"),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--dry-run", str(blob)], env=env)
    assert r.returncode == 0, r.stderr
    # plain open / xdg-open + path; not MdReader scheme
    assert "md-reader://" not in r.stdout
    assert str(blob) in r.stdout


def test_preview_without_last_path(tmp_path, monkeypatch):
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--preview"], env=env)
    assert r.returncode == 1
    assert "last_path" in (r.stderr + r.stdout).lower()


def test_dry_run_remembers_only_on_real_open(tmp_path):
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--dry-run", str(README)], env=env)
    assert r.returncode == 0
    assert not (tmp_path / "last_path").exists()
