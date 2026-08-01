#!/usr/bin/env bash
# One-shot install for grok-md-reader (macOS).
# Builds MdReader.app, links the Grok plugin, installs the tracking hook,
# and applies OS default apps so Grok tool-line Cmd+click opens correctly.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SET_DEFAULTS=1
DOCTOR_ONLY=0
DEFAULTS_ONLY=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  (default)           Full install: app + plugin + hook + OS defaults + doctor
  --no-set-defaults   Skip writing macOS default apps (still install app/plugin)
  --set-defaults      Only apply OS defaults from readers config (no rebuild)
  --doctor            Only run health check
  -h, --help          Show this help

After install, Cmd+click file:// paths on Grok tool lines use system open →
the default apps configured here (.md → MdReader, .pdf → Preview, …).
Plain chat text is not a hyperlink; use /open <path> as fallback.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-set-defaults) SET_DEFAULTS=0; shift ;;
    --set-defaults) DEFAULTS_ONLY=1; shift ;;
    --doctor) DOCTOR_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

APPLY="$ROOT/plugins/md-reader/scripts/apply_os_defaults.py"

if [[ "$DOCTOR_ONLY" -eq 1 ]]; then
  exec python3 "$APPLY" --doctor
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: MdReader.app requires macOS. On Linux you can still link the plugin" >&2
  echo "       and point config/readers.json at xdg-open / your editor." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required" >&2
  exit 1
fi

if [[ "$DEFAULTS_ONLY" -eq 1 ]]; then
  echo "==> Apply OS default apps (from readers config)"
  python3 "$APPLY"
  echo ""
  python3 "$APPLY" --doctor
  exit $?
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "error: swiftc not found. Install Xcode Command Line Tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

echo "==> [1/4] Build and install MdReader.app"
"$ROOT/viewer/scripts/build_app.sh" --install

echo "==> [2/4] Link Grok plugin"
mkdir -p "${HOME}/.grok/plugins"
ln -sfn "$ROOT/plugins/md-reader" "${HOME}/.grok/plugins/md-reader"
echo "    linked: ${HOME}/.grok/plugins/md-reader -> $ROOT/plugins/md-reader"

echo "==> [3/4] Install tracking hook (side-channel)"
"$ROOT/plugins/md-reader/scripts/install_sidechannel_hook.sh"

if [[ "$SET_DEFAULTS" -eq 1 ]]; then
  echo "==> [4/4] Apply OS default apps (Cmd+click / system open)"
  echo "    Maps .md → MdReader, .pdf → Preview, Office → Word/… when installed."
  echo "    Skip next time with: ./install.sh --no-set-defaults"
  python3 "$APPLY"
else
  echo "==> [4/4] Skip OS defaults (--no-set-defaults)"
  echo "    Apply later: ./install.sh --set-defaults"
fi

echo ""
echo "==> Doctor"
python3 "$APPLY" --doctor || true

echo ""
echo "Install complete."
echo ""
echo "Primary use (install-and-click):"
echo "  In Grok, Cmd+click a file path on a tool line (Write/Read/Edit)."
echo "  That uses system open → defaults just configured."
echo ""
echo "Fallback when the path is plain chat text (not a hyperlink):"
echo "  /open /absolute/or/relative/path"
echo "  /preview"
echo ""
echo "Re-check anytime:  ./install.sh --doctor"
