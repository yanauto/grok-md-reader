"""Unit tests for apply_os_defaults.py (no Launch Services writes)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "plugins" / "md-reader" / "scripts" / "apply_os_defaults.py"
EXAMPLE = ROOT / "plugins" / "md-reader" / "config" / "readers.example.json"


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
    assert EXAMPLE.is_file()


def test_print_plan_from_example(tmp_path):
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--print-plan"], env=env)
    assert r.returncode == 0, r.stderr
    plan = json.loads(r.stdout)
    assert isinstance(plan, list)
    assert plan, "plan should not be empty"
    # .md should map to md-reader with bundle id
    md_rows = [p for p in plan if p.get("ext") == ".md"]
    assert md_rows
    row = md_rows[0]
    assert row.get("app_key") == "md-reader"
    assert row.get("bundle_id") == "com.yanauto.mdreader"
    assert row.get("uti") == "net.daringfireball.markdown"
    # .pdf → preview
    pdf_rows = [p for p in plan if p.get("ext") == ".pdf"]
    assert pdf_rows
    assert pdf_rows[0].get("app_key") == "preview"
    assert pdf_rows[0].get("bundle_id") == "com.apple.Preview"


def test_dry_run_apply_does_not_fail_hard(tmp_path):
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--dry-run"], env=env)
    # On macOS should succeed; on other OS script returns OK skip
    assert r.returncode == 0, r.stderr + r.stdout
    out = r.stdout + r.stderr
    assert "summary:" in out or "macOS only" in out or "DRY-RUN" in out


def test_example_has_os_defaults_and_bundle_ids():
    data = json.loads(EXAMPLE.read_text(encoding="utf-8"))
    assert "os_defaults" in data
    apps = data["apps"]
    assert apps["md-reader"]["bundle_id"] == "com.yanauto.mdreader"
    assert apps["preview"]["bundle_id"] == "com.apple.Preview"
    assert ".md" in data["os_defaults"]["apply_extensions"]
    assert ".pdf" in data["os_defaults"]["apply_extensions"]
    # .txt must NOT be in OS defaults (too broad)
    assert ".txt" not in data["os_defaults"]["apply_extensions"]


def test_print_config_loads_example(tmp_path):
    env = {
        "GROK_PLUGIN_DATA": str(tmp_path),
        "GROK_PLUGIN_ROOT": str(ROOT / "plugins" / "md-reader"),
    }
    r = run(["--print-config"], env=env)
    assert r.returncode == 0
    data = json.loads(r.stdout)
    assert data["by_extension"][".md"] == "md-reader"
