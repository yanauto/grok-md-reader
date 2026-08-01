#!/usr/bin/env python3
"""Apply readers.json open policy to macOS Launch Services defaults.

Product path for Cmd+click on Grok tool-line file:// links:
  Grok → system open → default app (this script configures those defaults).

Usage:
  apply_os_defaults.py              # apply from readers config
  apply_os_defaults.py --dry-run
  apply_os_defaults.py --doctor
  apply_os_defaults.py --print-plan
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import subprocess
import sys
from pathlib import Path

EXIT_OK = 0
EXIT_FAIL = 1
EXIT_USAGE = 2

# Extension → UTI for Launch Services (macOS). Only types we intentionally claim.
EXT_TO_UTI: dict[str, str] = {
    ".md": "net.daringfireball.markdown",
    ".markdown": "net.daringfireball.markdown",
    ".mdc": "net.daringfireball.markdown",
    ".mdx": "net.daringfireball.markdown",
    ".pdf": "com.adobe.pdf",
    ".doc": "com.microsoft.word.doc",
    ".docx": "org.openxmlformats.wordprocessingml.document",
    ".ppt": "com.microsoft.powerpoint.ppt",
    ".pptx": "org.openxmlformats.presentationml.presentation",
    ".xls": "com.microsoft.excel.xls",
    ".xlsx": "org.openxmlformats.spreadsheetml.sheet",
}

# Fallback known app locations when mdfind is empty (common on fresh installs).
KNOWN_APP_PATHS: dict[str, list[Path]] = {
    "com.yanauto.mdreader": [
        Path.home() / "Applications" / "MdReader.app",
        Path("/Applications/MdReader.app"),
    ],
    "com.apple.Preview": [
        Path("/System/Applications/Preview.app"),
        Path("/Applications/Preview.app"),
    ],
}


def plugin_root() -> Path:
    env = os.environ.get("GROK_PLUGIN_ROOT") or os.environ.get("CLAUDE_PLUGIN_ROOT")
    if env:
        return Path(env).expanduser().resolve()
    # scripts/thisfile → plugin root parents[1]
    return Path(__file__).resolve().parents[1]


def data_dir() -> Path:
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


def load_readers_config() -> dict:
    candidates = [
        data_dir() / "readers.json",
        plugin_root() / "config" / "readers.example.json",
    ]
    for path in candidates:
        if path.is_file():
            try:
                return json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
    return {"default": "system", "by_extension": {}, "apps": {}, "os_defaults": {}}


def helper_paths() -> tuple[Path, Path]:
    scripts = Path(__file__).resolve().parent
    src = scripts / "ls_default_handler.swift"
    cache = scripts / ".cache"
    bin_path = cache / "ls_default_handler"
    return src, bin_path


def ensure_helper() -> Path:
    src, bin_path = helper_paths()
    if not src.is_file():
        raise FileNotFoundError(f"missing helper source: {src}")
    bin_path.parent.mkdir(parents=True, exist_ok=True)
    need_build = True
    if bin_path.is_file():
        if bin_path.stat().st_mtime >= src.stat().st_mtime:
            need_build = False
    if need_build:
        r = subprocess.run(
            ["swiftc", "-O", "-o", str(bin_path), str(src)],
            capture_output=True,
            text=True,
        )
        if r.returncode != 0:
            raise RuntimeError(f"swiftc failed: {r.stderr or r.stdout}")
    return bin_path


def ls_get(helper: Path, uti: str) -> str | None:
    r = subprocess.run([str(helper), "get", uti], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return (r.stdout or "").strip() or None


def ls_set(helper: Path, uti: str, bundle_id: str, dry_run: bool) -> tuple[bool, str]:
    if dry_run:
        return True, f"DRY-RUN: set {uti} -> {bundle_id}"
    r = subprocess.run(
        [str(helper), "set", uti, bundle_id],
        capture_output=True,
        text=True,
    )
    if r.returncode == 0:
        return True, (r.stdout or "").strip() or f"ok {uti} -> {bundle_id}"
    err = (r.stderr or r.stdout or "set failed").strip()
    return False, err


def find_app(bundle_id: str) -> Path | None:
    try:
        r = subprocess.run(
            ["mdfind", f"kMDItemCFBundleIdentifier == '{bundle_id}'"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        for line in (r.stdout or "").splitlines():
            p = Path(line.strip())
            if p.suffix == ".app" and p.is_dir():
                return p
    except (OSError, subprocess.TimeoutExpired):
        pass
    for p in KNOWN_APP_PATHS.get(bundle_id, []):
        if p.is_dir():
            return p
    # MdReader dist during dev
    if bundle_id == "com.yanauto.mdreader":
        pr = plugin_root()
        dist = pr.parent.parent / "viewer" / "dist" / "MdReader.app"
        if dist.is_dir():
            return dist
    return None


def apply_extensions(cfg: dict) -> list[str]:
    od = cfg.get("os_defaults") or {}
    listed = od.get("apply_extensions")
    if isinstance(listed, list) and listed:
        return [str(x).lower() if str(x).startswith(".") else f".{x}".lower() for x in listed]
    # Safe default: document types we route; skip .txt/.html (too broad as OS default)
    return [
        ".md",
        ".markdown",
        ".mdc",
        ".mdx",
        ".pdf",
        ".doc",
        ".docx",
        ".ppt",
        ".pptx",
        ".xls",
        ".xlsx",
    ]


def build_plan(cfg: dict) -> list[dict]:
    """Return plan rows: {ext, uti, app_key, bundle_id, app_path|None, skip_reason|None}."""
    by_ext = cfg.get("by_extension") or {}
    apps = cfg.get("apps") or {}
    plan: list[dict] = []
    seen_uti: set[str] = set()

    for ext in apply_extensions(cfg):
        app_key = by_ext.get(ext)
        if not app_key:
            plan.append(
                {
                    "ext": ext,
                    "uti": EXT_TO_UTI.get(ext),
                    "app_key": None,
                    "bundle_id": None,
                    "app_path": None,
                    "skip_reason": "no by_extension mapping",
                }
            )
            continue
        if app_key == "system":
            plan.append(
                {
                    "ext": ext,
                    "uti": EXT_TO_UTI.get(ext),
                    "app_key": app_key,
                    "bundle_id": None,
                    "app_path": None,
                    "skip_reason": "app key is system (leave OS default)",
                }
            )
            continue
        app_def = apps.get(app_key) or {}
        bundle_id = None
        if isinstance(app_def, dict):
            bundle_id = app_def.get("bundle_id")
        uti = EXT_TO_UTI.get(ext)
        if not uti:
            plan.append(
                {
                    "ext": ext,
                    "uti": None,
                    "app_key": app_key,
                    "bundle_id": bundle_id,
                    "app_path": None,
                    "skip_reason": "no UTI for extension",
                }
            )
            continue
        if uti in seen_uti:
            plan.append(
                {
                    "ext": ext,
                    "uti": uti,
                    "app_key": app_key,
                    "bundle_id": bundle_id,
                    "app_path": None,
                    "skip_reason": f"UTI already planned ({uti})",
                }
            )
            continue
        if not bundle_id:
            plan.append(
                {
                    "ext": ext,
                    "uti": uti,
                    "app_key": app_key,
                    "bundle_id": None,
                    "app_path": None,
                    "skip_reason": f"apps.{app_key} missing bundle_id",
                }
            )
            continue
        app_path = find_app(str(bundle_id))
        if app_path is None:
            plan.append(
                {
                    "ext": ext,
                    "uti": uti,
                    "app_key": app_key,
                    "bundle_id": str(bundle_id),
                    "app_path": None,
                    "skip_reason": f"app not installed ({bundle_id})",
                }
            )
            continue
        seen_uti.add(uti)
        plan.append(
            {
                "ext": ext,
                "uti": uti,
                "app_key": app_key,
                "bundle_id": str(bundle_id),
                "app_path": str(app_path),
                "skip_reason": None,
            }
        )
    return plan


def cmd_print_plan(cfg: dict) -> int:
    plan = build_plan(cfg)
    print(json.dumps(plan, indent=2, ensure_ascii=False))
    return EXIT_OK


def is_critical_default(row: dict) -> bool:
    """md-reader must win; other types are best-effort (macOS may lock PDF to Chrome)."""
    return row.get("app_key") == "md-reader"


def cmd_apply(cfg: dict, dry_run: bool) -> int:
    if platform.system() != "Darwin":
        print("apply_os_defaults: macOS only (skip)", file=sys.stderr)
        return EXIT_OK

    try:
        helper = ensure_helper()
    except (FileNotFoundError, RuntimeError) as e:
        print(f"failed to build helper: {e}", file=sys.stderr)
        return EXIT_FAIL

    plan = build_plan(cfg)
    applied = 0
    skipped = 0
    soft_fail = 0
    hard_fail = 0

    for row in plan:
        if row["skip_reason"]:
            print(f"skip {row['ext']}: {row['skip_reason']}")
            skipped += 1
            continue
        uti = row["uti"]
        bundle_id = row["bundle_id"]
        ok, msg = ls_set(helper, uti, bundle_id, dry_run=dry_run)
        if ok:
            print(msg if dry_run else f"set {row['ext']} ({uti}) -> {bundle_id}  [{row['app_path']}]")
            applied += 1
            continue
        # Real set failed or OS ignored the change
        if dry_run:
            print(msg)
            applied += 1
            continue
        critical = is_critical_default(row)
        level = "FAIL" if critical else "warn"
        print(f"{level} {row['ext']}: {msg}", file=sys.stderr)
        if not critical:
            print(
                f"     (best-effort) Cmd+click still opens via current default; "
                f"to force {bundle_id}: Finder → file → ⌘I → Open with → Change All",
                file=sys.stderr,
            )
            soft_fail += 1
        else:
            hard_fail += 1

    print(
        f"summary: applied={applied} skipped={skipped} "
        f"soft_fail={soft_fail} hard_fail={hard_fail}"
    )
    return EXIT_FAIL if hard_fail else EXIT_OK


def cmd_doctor(cfg: dict) -> int:
    """Report install health for install-and-click path."""
    issues: list[str] = []
    print("== md-reader doctor ==")

    # App
    app = find_app("com.yanauto.mdreader")
    if app:
        print(f"ok  MdReader.app: {app}")
    else:
        print("FAIL MdReader.app not found (run ./install.sh or viewer/scripts/build_app.sh --install)")
        issues.append("mdreader-missing")

    # Plugin link
    plugin_link = Path.home() / ".grok" / "plugins" / "md-reader"
    if plugin_link.exists():
        print(f"ok  plugin link: {plugin_link} -> {plugin_link.resolve()}")
    else:
        print(f"FAIL plugin not linked at {plugin_link}")
        issues.append("plugin-missing")

    # Hook
    hook = Path.home() / ".grok" / "hooks" / "md-reader-sidechannel.json"
    if hook.is_file():
        print(f"ok  sidechannel hook: {hook}")
    else:
        print(f"warn sidechannel hook missing: {hook} (optional for click path)")

    if platform.system() != "Darwin":
        print("warn OS defaults: non-macOS (Cmd+click uses xdg defaults; use /open)")
        print(f"doctor: {'FAIL' if issues else 'OK'} ({len(issues)} hard issue(s))")
        return EXIT_FAIL if issues else EXIT_OK

    try:
        helper = ensure_helper()
    except (FileNotFoundError, RuntimeError) as e:
        print(f"FAIL helper: {e}")
        issues.append("helper")
        print(f"doctor: FAIL ({len(issues)} hard issue(s))")
        return EXIT_FAIL

    # Check planned defaults (md-reader critical; others warn-only)
    plan = build_plan(cfg)
    warnings = 0
    for row in plan:
        if row["skip_reason"] or not row["uti"] or not row["bundle_id"]:
            continue
        current = ls_get(helper, row["uti"])
        want = row["bundle_id"]
        if current == want:
            print(f"ok  default {row['ext']} ({row['uti']}) -> {current}")
            continue
        if is_critical_default(row):
            print(
                f"FAIL default {row['ext']} ({row['uti']}) -> {current or 'none'} "
                f"(want {want})"
            )
            issues.append(f"default-{row['ext']}")
        else:
            print(
                f"warn default {row['ext']} ({row['uti']}) -> {current or 'none'} "
                f"(want {want}; Cmd+click still opens with current app)"
            )
            warnings += 1

    print("")
    print("Click path (Grok tool-line file://):")
    print("  Cmd+click → system open → OS default app above.")
    print("  Plain chat text paths are NOT hyperlinks — use /open <path>.")
    print("")
    if issues:
        print(f"doctor: FAIL ({len(issues)} hard issue(s), {warnings} warn(s))")
        print("fix: ./install.sh   # or: python3 plugins/md-reader/scripts/apply_os_defaults.py")
        return EXIT_FAIL
    if warnings:
        print(f"doctor: OK ({warnings} non-critical default warn(s))")
    else:
        print("doctor: OK")
    return EXIT_OK


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Apply md-reader OS default apps from readers.json")
    parser.add_argument("--dry-run", action="store_true", help="print actions without writing LS")
    parser.add_argument("--doctor", action="store_true", help="check install + defaults")
    parser.add_argument("--print-plan", action="store_true", help="print JSON apply plan and exit")
    parser.add_argument(
        "--print-config",
        action="store_true",
        help="print resolved readers config path sources",
    )
    args = parser.parse_args(argv)

    cfg = load_readers_config()

    if args.print_config:
        print(json.dumps(cfg, indent=2, ensure_ascii=False))
        return EXIT_OK
    if args.print_plan:
        return cmd_print_plan(cfg)
    if args.doctor:
        return cmd_doctor(cfg)
    return cmd_apply(cfg, dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
