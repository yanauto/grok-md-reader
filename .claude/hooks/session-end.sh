#!/usr/bin/env bash
# Project Memory System - SessionEnd hook (bash)
# 把本次会话的 transcript 复制到 .claude/sessions/raw/ 作为兜底备份
# 不动主记忆文件

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RAW_DIR="$PROJECT_ROOT/.claude/sessions/raw"
mkdir -p "$RAW_DIR"

TIMESTAMP=$(date +%Y-%m-%d-%H%M)

# 读 stdin
INPUT=$(cat)

if [ -z "$INPUT" ]; then
    exit 0
fi

# 尝试解析 transcript_path
TRANSCRIPT_PATH=""
if [ -x /usr/bin/python3 ]; then
    TRANSCRIPT_PATH=$(echo "$INPUT" | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
fi

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    EXT="${TRANSCRIPT_PATH##*.}"
    cp -f "$TRANSCRIPT_PATH" "$RAW_DIR/$TIMESTAMP.$EXT"
else
    # fallback: 存原始 event
    echo "$INPUT" > "$RAW_DIR/$TIMESTAMP.event.json"
fi

exit 0
