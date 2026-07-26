#!/usr/bin/env bash
# Project Memory System - SessionStart hook (bash) v4.1
# v4.0 (2026-07-17 Vitals 底座): 项目实况迁入 projects.db(vitals proj 命令族),本 hook 机器代跑只读查询并注入;
#   叙事(decisions/ ADR)仍是 docs/ 下的 md。CLI 失败显式降级不静默;proj 读命令无游标副作用,重复注入天然无害。
# v4.1 (2026-07-17 精简): 按 11 个已装项目的实际使用度砍掉 feature 工作区/compact 快照/INDEX——只留真被用的。
# 1. 注入 项目状态(proj now)+ 近 7 天事件流
# 2. 机械闸:宪法体积 / 铁律条数 / 距上次收尾事件天数——全绿静默
# 3. 清理 30 天前 raw transcript

set +e  # 不要因为单个失败终止

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_NAME="grok-md-reader"
RAW_DIR="$PROJECT_ROOT/.claude/sessions/raw"
VITALS_BIN="/opt/homebrew/bin/vitals"

# --- 1. 机器代跑 vitals proj 只读两查(全部无副作用;任何失败显式降级) ---
PROJ_NOW=""
PROJ_RECENT=""
PROJ_FAIL=""
if [ -x "$VITALS_BIN" ]; then
    PROJ_NOW="$("$VITALS_BIN" proj now "$PROJECT_NAME" --pretty 2>/dev/null)" || PROJ_FAIL="proj now 失败"
    PROJ_RECENT="$("$VITALS_BIN" proj recent --project "$PROJECT_NAME" --days 7 --limit 10 --pretty 2>/dev/null)" || PROJ_FAIL="${PROJ_FAIL:+$PROJ_FAIL；}recent 失败"
    # 距上次收尾事件天数(机械闸用):取最近 1 条事件的 ts
    LAST_EVENT_TS="$("$VITALS_BIN" proj recent --project "$PROJECT_NAME" --days 365 --limit 1 2>/dev/null | /usr/bin/python3 -c "import json,sys
try:
    evs=json.load(sys.stdin); print(evs[0]['ts'] if evs else '')
except Exception: print('')" 2>/dev/null)"
else
    PROJ_FAIL="vitals CLI 不存在或不可执行($VITALS_BIN)"
    LAST_EVENT_TS=""
fi
export PROJ_NOW PROJ_RECENT PROJ_FAIL LAST_EVENT_TS PROJECT_NAME PROJECT_ROOT

# --- 2. 注入 + 机械闸 ---
if [ -x /usr/bin/python3 ]; then
    /usr/bin/python3 <<'PYEOF'
import json, os, re, time
from datetime import datetime, timezone

root = os.environ.get('PROJECT_ROOT', '')
name = os.environ.get('PROJECT_NAME', '')

def emit(ctx):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart", "additionalContext": ctx}}, ensure_ascii=False))

def gates():
    """机械闸:周期性卫生从'靠自觉'改成'开场机器提醒'。全绿返回空串。"""
    warns = []
    try:
        cpath = os.path.join(root, 'CLAUDE.md')
        if os.path.isfile(cpath):
            raw = open(cpath, encoding='utf-8', errors='replace').read()
            kb = len(raw.encode('utf-8')) / 1024
            if kb > 10:
                warns.append("⚠️ CLAUDE.md 已 %.1fKB(>10KB)——常驻热层膨胀，和用户确认后精简" % kb)
            m = re.search(r'## 项目铁律.*?\n(.*?)(?=\n## |\Z)', raw, re.S)
            if m:
                n = len(re.findall(r'^\s*(?:\d+\.|[-*])\s+\S', m.group(1), re.M))
                if n > 15:
                    warns.append("⚠️ 项目铁律已 %d 条(>15 软上限)——和用户确认后去重/合并/退役(退役先 proj log 留痕)" % n)
        # 距上次收尾/进展事件天数(v4.0:从 projects.db 事件流算,不再看 progress.md mtime)
        last_ts = os.environ.get('LAST_EVENT_TS', '').strip()
        if last_ts:
            try:
                dt = datetime.strptime(last_ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                days = int((time.time() - dt.timestamp()) / 86400)
                if days > 7:
                    warns.append("⚠️ 距上次 wrap-up/进展事件已 %d 天——上次收尾可能没做,本次结束记得 /wrap-up" % days)
            except Exception:
                pass
    except Exception:
        pass
    return ("\n\n" + "\n".join(warns)) if warns else ""

fail = os.environ.get('PROJ_FAIL', '').strip()
now_block = os.environ.get('PROJ_NOW', '').strip()
recent_block = os.environ.get('PROJ_RECENT', '').strip()

if fail:
    emit("⚠️ SessionStart：项目实况拉取失败（%s）。开工前先手动跑 "
         "`vitals proj now %s --pretty` + `vitals proj recent --project %s --days 7 --pretty`；"
         "仍拉不到就向用户声明「项目实况不可用」，别凭印象开工。" % (fail, name, name) + gates())
else:
    parts = ["## 项目实况（SessionStart hook 机器代跑 `vitals proj`，projects.db 只读查询）\n"]
    parts.append("**状态（proj now）**：\n" + (now_block or "(项目尚无状态记录——首次会话?先问用户当前目标)"))
    parts.append("\n**近 7 天事件流（新在前）**：\n" + (recent_block or "(无事件)"))
    parts.append("\n---\n请先复述状态里的「下一步」，告诉用户「上次到 X，下次该做 Y」，等用户确认或修正再动手。"
                 "\n历史决策(为什么这么定)按需读 `docs/decisions/`;刚经历 context 压缩也一样——库是持久的,重跑上面两条只读命令即可恢复。")
    emit("\n".join(parts) + gates())
PYEOF
else
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"⚠️ SessionStart：未找到 /usr/bin/python3，无法自动注入项目实况。请手动跑 vitals proj now grok-md-reader --pretty，别凭印象开工。"}}'
fi

# --- 3. 清 30 天前的 raw ---
if [ -d "$RAW_DIR" ]; then
    find "$RAW_DIR" -type f -mtime +30 -delete 2>/dev/null
fi

exit 0
