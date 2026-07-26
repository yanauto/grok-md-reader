#!/usr/bin/env bash
# Install PostToolUse side-channel as a *global* Grok hook.
# (2026-07-26: plugin-bundled hooks.json is discovered but may not fire in
# headless/TUI until Grok expands plugin hook files into the registry;
# global hooks are the reliable path — same script, same data dir.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/hooks/on_md_write.py"
DATA="${GROK_PLUGIN_DATA:-$HOME/.grok/plugin-data/user/md-reader}"
DEST_DIR="$HOME/.grok/hooks"
DEST="$DEST_DIR/md-reader-sidechannel.json"

mkdir -p "$DEST_DIR" "$DATA"
cat > "$DEST" <<EOF
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "write|search_replace",
        "hooks": [
          {
            "type": "command",
            "command": "python3 $SCRIPT",
            "timeout": 5,
            "env": {
              "GROK_PLUGIN_DATA": "$DATA"
            }
          }
        ]
      }
    ]
  }
}
EOF
echo "installed: $DEST"
echo "data dir:  $DATA"
echo "disable:   touch $DATA/hook_disabled   OR  MD_READER_HOOK_DISABLE=1"
echo "re-enable: rm $DATA/hook_disabled"
