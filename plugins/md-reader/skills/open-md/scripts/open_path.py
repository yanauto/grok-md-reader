#!/usr/bin/env python3
"""Open a local file in MdReader (companion window) or a configured fallback app."""

from __future__ import annotations

import argparse
import json
import os
import platform
import subprocess
import sys
import urllib.parse
from pathlib import Path

# Exit codes
EXIT_OK = 0
EXIT_FAIL = 1  # not found / open failed / no last_path
EXIT_USAGE = 2  # bad args / URL refused / not a file

SCHEME = "md-reader"
DEFAULT_APP_NAME = "MdReader"


def plugin_root() -> Path:
    env = os.environ.get("GROK_PLUGIN_ROOT") or os.environ.get("CLAUDE_PLUGIN_ROOT")
    if env:
        return Path(env).expanduser().resolve()
    # skills/open-md/scripts/thisfile → plugin root is parents[2]
    return Path(__file__).resolve().parents[2]


def repo_root_guess() -> Path | None:
    """Dev layout: plugins/md-reader → repo root two levels up."""
    pr = plugin_root()
    candidate = pr.parent.parent
    if (candidate / "viewer").is_dir():
        return candidate
    return None


def data_dir() -> Path:
    """Align with on_md_write.py: GROK_PLUGIN_DATA → plugin-data/*/md-reader → config."""
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


def last_path_file() -> Path:
    return data_dir() / "last_path"


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
    return {"default": "md-reader", "by_extension": {}, "apps": {}}


def resolve_target(path_s: str) -> Path:
    p = Path(path_s).expanduser()
    if not p.is_absolute():
        p = (Path.cwd() / p).resolve()
    else:
        p = p.resolve()
    return p


def remember(path: Path) -> None:
    try:
        last_path_file().write_text(str(path), encoding="utf-8")
    except OSError:
        pass


def scheme_url_for(path: Path) -> str:
    # md-reader://open?path=<percent-encoded absolute path>
    q = urllib.parse.urlencode({"path": str(path)})
    return f"{SCHEME}://open?{q}"


def mdreader_app_candidates() -> list[Path]:
    home = Path.home()
    candidates = [
        home / "Applications" / "MdReader.app",
        Path("/Applications/MdReader.app"),
    ]
    repo = repo_root_guess()
    if repo is not None:
        candidates.insert(0, repo / "viewer" / "dist" / "MdReader.app")
    # Also honor env override
    env = os.environ.get("MD_READER_APP")
    if env:
        candidates.insert(0, Path(env).expanduser())
    return candidates


def find_mdreader_app() -> Path | None:
    for p in mdreader_app_candidates():
        if p.is_dir() and (p / "Contents" / "MacOS" / "MdReader").is_file():
            return p
    return None


def open_with_mdreader(path: Path, dry_run: bool) -> int:
    """Prefer custom URL scheme; fall back to open -a MdReader.app."""
    system = platform.system()
    if system != "Darwin":
        print("md-reader viewer currently ships for macOS only", file=sys.stderr)
        return EXIT_FAIL

    url = scheme_url_for(path)
    app = find_mdreader_app()

    if app is not None:
        # Explicit app path is most reliable before Launch Services indexes the scheme
        cmd = ["open", "-a", str(app), url]
    else:
        cmd = ["open", url]

    if dry_run:
        print("DRY-RUN:", " ".join(cmd))
        if app is None:
            print("DRY-RUN: note: MdReader.app not found in candidates", file=sys.stderr)
        return EXIT_OK

    try:
        r = subprocess.run(cmd, check=False, capture_output=True, text=True)
        if r.returncode != 0:
            # Fallback: open file with app bundle directly
            if app is not None:
                cmd2 = ["open", "-a", str(app), str(path)]
                r2 = subprocess.run(cmd2, check=False, capture_output=True, text=True)
                if r2.returncode != 0:
                    err = (r.stderr or r2.stderr or "open failed").strip()
                    print(f"failed to open with MdReader: {err}", file=sys.stderr)
                    return EXIT_FAIL
            else:
                err = (r.stderr or "open failed; is MdReader.app installed?").strip()
                print(f"failed to open with MdReader: {err}", file=sys.stderr)
                print(
                    "hint: build/install viewer → ./viewer/scripts/build_app.sh --install",
                    file=sys.stderr,
                )
                return EXIT_FAIL
        print(f"opened (md-reader): {path}")
        remember(path)
        return EXIT_OK
    except OSError as e:
        print(f"failed to open: {e}", file=sys.stderr)
        return EXIT_FAIL


def open_with_command(cmd: list[str], path: Path, dry_run: bool, label: str) -> int:
    full = cmd + [str(path)]
    if dry_run:
        print("DRY-RUN:", " ".join(full))
        return EXIT_OK
    try:
        subprocess.run(full, check=False)
        print(f"opened ({label}): {path}")
        remember(path)
        return EXIT_OK
    except OSError as e:
        print(f"failed to open: {e}", file=sys.stderr)
        return EXIT_FAIL


def resolve_app_key(cfg: dict, path: Path) -> str:
    by_ext = cfg.get("by_extension") or {}
    ext = path.suffix.lower()
    if ext in by_ext:
        return str(by_ext[ext])
    return str(cfg.get("default") or "md-reader")


def open_target(path: Path, dry_run: bool, force_app: str | None) -> int:
    cfg = load_readers_config()
    app_key = force_app or resolve_app_key(cfg, path)
    apps = cfg.get("apps") or {}

    if app_key in ("md-reader", "viewer"):
        return open_with_mdreader(path, dry_run)

    system = platform.system().lower()  # darwin / linux
    plat = "darwin" if system == "darwin" else system
    app_def = apps.get(app_key)
    if isinstance(app_def, dict) and plat in app_def:
        cmd = list(app_def[plat])
        return open_with_command(cmd, path, dry_run, app_key)

    # Unknown app key → system open
    if system == "darwin":
        return open_with_command(["open"], path, dry_run, "system")
    if system == "linux":
        return open_with_command(["xdg-open"], path, dry_run, "system")
    print(f"unsupported platform: {system}", file=sys.stderr)
    return EXIT_USAGE


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="md-reader open helper")
    parser.add_argument("path", nargs="?", help="file to open")
    parser.add_argument("--preview", action="store_true", help="open last remembered path")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--print-config", action="store_true")
    parser.add_argument(
        "--app",
        help="override readers.json app key (md-reader|system|typora|…)",
    )
    parser.add_argument(
        "--which-viewer",
        action="store_true",
        help="print resolved MdReader.app path (or empty) and exit",
    )
    args = parser.parse_args(argv)

    if args.print_config:
        print(json.dumps(load_readers_config(), indent=2, ensure_ascii=False))
        return EXIT_OK

    if args.which_viewer:
        app = find_mdreader_app()
        print(str(app) if app else "")
        return EXIT_OK if app else EXIT_FAIL

    if args.preview:
        lp = last_path_file()
        if not lp.is_file():
            print("no last_path recorded; use /open <path> first", file=sys.stderr)
            return EXIT_FAIL
        path_s = lp.read_text(encoding="utf-8").strip()
        if not path_s:
            print("no last_path recorded; use /open <path> first", file=sys.stderr)
            return EXIT_FAIL
    else:
        if not args.path:
            print("usage: open_path.py <path> | --preview", file=sys.stderr)
            return EXIT_USAGE
        path_s = args.path

    if path_s.startswith(("http://", "https://", "file://")):
        print("refusing URL; local files only", file=sys.stderr)
        return EXIT_USAGE

    target = resolve_target(path_s)
    if not target.exists():
        print(f"not found: {target}", file=sys.stderr)
        return EXIT_FAIL
    if not target.is_file():
        print(f"not a file: {target}", file=sys.stderr)
        return EXIT_USAGE

    return open_target(target, dry_run=args.dry_run, force_app=args.app)


if __name__ == "__main__":
    raise SystemExit(main())
