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


def test_print_config():
    r = run(["--print-config"])
    assert r.returncode == 0
    data = json.loads(r.stdout)
    assert "default" in data
    assert data["default"] in ("md-reader", "system")


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
