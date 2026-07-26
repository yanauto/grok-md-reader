#!/usr/bin/env bash
# One-shot install for grok-md-reader (macOS).
# Builds MdReader.app, links the Grok plugin, installs the tracking hook.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: MdReader.app requires macOS. On Linux you can still link the plugin" >&2
  echo "       and point config/readers.json at xdg-open / your editor." >&2
  exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "error: swiftc not found. Install Xcode Command Line Tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required" >&2
  exit 1
fi

echo "==> [1/3] Build and install MdReader.app"
"$ROOT/viewer/scripts/build_app.sh" --install

echo "==> [2/3] Link Grok plugin"
mkdir -p "${HOME}/.grok/plugins"
ln -sfn "$ROOT/plugins/md-reader" "${HOME}/.grok/plugins/md-reader"
echo "    linked: ${HOME}/.grok/plugins/md-reader -> $ROOT/plugins/md-reader"

echo "==> [3/3] Install tracking hook (side-channel)"
"$ROOT/plugins/md-reader/scripts/install_sidechannel_hook.sh"

echo ""
echo "Install complete."
echo ""
echo "Verify:"
echo "  grok inspect"
echo "  python3 plugins/md-reader/skills/open-md/scripts/open_path.py README.md"
echo ""
echo "In a Grok session:  /open README.md   or   /preview"
echo "Optional: set MdReader as the default app for .md (Finder → ⌘I → Open with)."
