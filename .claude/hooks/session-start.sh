#!/usr/bin/env bash
# Project Memory System - SessionStart hook (bash) v5.1
# v5.1 (2026-07-27): 控制面简报——仪表盘 + 固定导航 + 最近 OPS/决策指针；不再全文倾倒 7 日 session
# v5.0: 取消宪法体积/铁律条数告警
# 1. 只读 vitals proj now + recent(JSON)
# 2. 拼框架简报 + 记忆健康闸
# 3. 清 30 天前 raw

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_NAME="grok-md-reader"
RAW_DIR="$PROJECT_ROOT/.claude/sessions/raw"
VITALS_BIN="/opt/homebrew/bin/vitals"

PROJ_NOW=""
PROJ_RECENT_JSON=""
PROJ_FAIL=""
LAST_EVENT_TS=""

if [ -x "$VITALS_BIN" ]; then
    PROJ_NOW="$("$VITALS_BIN" proj now "$PROJECT_NAME" --pretty 2>/dev/null)" || PROJ_FAIL="proj now 失败"
    # JSON 供解析 OPS/decision；pretty 不再直接注入
    PROJ_RECENT_JSON="$("$VITALS_BIN" proj recent --project "$PROJECT_NAME" --days 30 --limit 40 2>/dev/null)" || PROJ_FAIL="${PROJ_FAIL:+$PROJ_FAIL；}recent 失败"
    LAST_EVENT_TS="$(printf '%s' "$PROJ_RECENT_JSON" | /usr/bin/python3 -c "import json,sys
try:
    evs=json.load(sys.stdin); print(evs[0]['ts'] if evs else '')
except Exception: print('')" 2>/dev/null)"
else
    PROJ_FAIL="vitals CLI 不存在或不可执行($VITALS_BIN)"
fi

export PROJ_NOW PROJ_RECENT_JSON PROJ_FAIL LAST_EVENT_TS PROJECT_NAME PROJECT_ROOT

if [ -x /usr/bin/python3 ]; then
    /usr/bin/python3 <<'PYEOF'
import json, os, time, re
from datetime import datetime, timezone
from pathlib import Path

root = os.environ.get("PROJECT_ROOT", "")
name = os.environ.get("PROJECT_NAME", "")

def emit(ctx: str) -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": ctx,
                }
            },
            ensure_ascii=False,
        )
    )

def parse_events(raw: str):
    if not raw or not raw.strip():
        return []
    try:
        data = json.loads(raw)
        return data if isinstance(data, list) else []
    except Exception:
        return []

def extract_ops(evs, limit=3):
    out = []
    for e in evs:
        s = (e.get("summary") or "") + " " + (e.get("report_ref") or "")
        if "[OPS]" in s or (e.get("action") == "ops"):
            line = (e.get("summary") or "").strip()
            ref = (e.get("report_ref") or "").strip()
            if ref and "→" not in line and "->" not in line:
                line = f"{line} → {ref}" if line else f"[OPS] → {ref}"
            if line:
                out.append(line)
        if len(out) >= limit:
            break
    return out

def extract_decisions(evs, limit=2):
    out = []
    for e in evs:
        s = (e.get("summary") or "").strip()
        act = e.get("action") or ""
        if act == "decision" or re.search(r"\bADR-\d+", s, re.I):
            if s:
                out.append(s)
        if len(out) >= limit:
            break
    return out

def memory_health(evs) -> list:
    warns = []
    last_ts = os.environ.get("LAST_EVENT_TS", "").strip()
    if last_ts:
        try:
            dt = datetime.strptime(last_ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            days = int((time.time() - dt.timestamp()) / 86400)
            if days > 7:
                warns.append(f"⚠️ 距上次项目事件已 {days} 天——结束记得 /wrap-up")
        except Exception:
            pass
    # 内容面探针（控制面健康）
    for rel, label in (
        ("docs/代码地图.md", "工程地图"),
        ("docs/工程手册.md", "工程手册"),
    ):
        p = Path(root) / rel
        if root and not p.is_file():
            warns.append(f"⚠️ 缺少 {label}（{rel}）——按 v5 应补齐")
    return warns

fail = os.environ.get("PROJ_FAIL", "").strip()
now_block = os.environ.get("PROJ_NOW", "").strip()
evs = parse_events(os.environ.get("PROJ_RECENT_JSON", ""))
ops = extract_ops(evs)
decs = extract_decisions(evs)
health = memory_health(evs)

if fail:
    emit(
        f"⚠️ SessionStart：项目实况拉取失败（{fail}）。开工前手动：\n"
        f"`vitals proj now {name} --pretty`\n"
        f"`vitals proj recent --project {name} --days 7 --pretty`\n"
        f"仍失败则声明「项目实况不可用」，别凭印象开工。"
        + (("\n\n" + "\n".join(health)) if health else "")
    )
else:
    parts = [
        "## 项目实况（控制面简报 · 对齐工程记忆 v5）\n",
        "### 仪表盘（proj now）\n",
        now_block or "（尚无状态——先问用户当前目标，再 `vitals proj now` 写入）",
        "\n\n### 固定导航（内容面 · 按需 Read，勿通读 cold 区）\n",
        "- 动代码 → `docs/代码地图.md`\n",
        "- 接口 / 环境 / 数据 → `docs/工程手册.md`\n",
        "- 逐步可复跑操作 → `docs/playbooks/`\n",
        "- 为什么 → `docs/decisions/`\n",
        "- 日文件 → `docs/sessions/`（仅日层）\n",
        "- **默认不读** → `docs/handoffs/`、`.claude/sessions/raw/`\n",
        "\n### 最近 OPS（可复跑指针 · ≤3）\n",
    ]
    if ops:
        parts.extend(f"- {x}\n" for x in ops)
    else:
        parts.append("- （无 · 有部署/联调打通时 wrap-up 须写 `[OPS] … → path`）\n")
    parts.append("\n### 最近决策指针（≤2）\n")
    if decs:
        parts.extend(f"- {x}\n" for x in decs)
    else:
        parts.append("- （无）\n")
    if health:
        parts.append("\n### 记忆健康\n")
        parts.extend(f"- {w}\n" for w in health)
    parts.append(
        "\n---\n"
        "请先**复述仪表盘里的「下一步」**，告诉用户「上次到 X，下一步 Y」，**等确认再动手**。\n"
        "需要完整事件流时再跑：`vitals proj recent --project "
        + name
        + " --days 7 --pretty`（开场不预灌长列表）。\n"
        "压缩后：重跑 `proj now` + 本 hook 逻辑即可恢复控制面。"
    )
    emit("".join(parts))
PYEOF
else
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"⚠️ SessionStart：未找到 /usr/bin/python3。请手动 vitals proj now grok-md-reader --pretty。"}}'
fi

if [ -d "$RAW_DIR" ]; then
    find "$RAW_DIR" -type f -mtime +30 -delete 2>/dev/null
fi

exit 0
