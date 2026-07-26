#!/usr/bin/env bash
# Project Memory System - UserPromptSubmit hook (bash)
# v3.0: 对用户本轮输入做「收尾短语」字面检测——机械 grep,不靠模型监听。
# 命中 → 注入提示,让 AI 向用户**确认一句**再走 /wrap-up(确认闸门,绝不自行启动收尾)。
# 设计依据:概率模型当字符串监听器会幻触发;字面匹配交给机器,判断(真收尾还是转述)交给确认。

set +e

INPUT=$(cat)
if [ -z "$INPUT" ]; then exit 0; fi

if [ -x /usr/bin/python3 ]; then
    INPUT="$INPUT" /usr/bin/python3 <<'PYEOF'
import json, os

raw = os.environ.get('INPUT', '')
try:
    prompt = json.loads(raw).get('prompt', '')
except Exception:
    prompt = ''

PHRASES = ["这次对话结束了", "今天到这了", "保存这次成果", "这次有价值",
           "先这样吧", "明天再说", "下次聊"]
hit = next((p for p in PHRASES if p in prompt), None)

if hit:
    ctx = ("⚠️ 机械检测：用户本轮输入含疑似收尾短语「%s」。"
           "若用户不是显式调用 /wrap-up，请先问一句「要走 /wrap-up 收尾吗？」，"
           "**得到肯定答复才执行**；用户若只是引用/转述/说别的，继续正常对话即可。" % hit)
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit", "additionalContext": ctx}}, ensure_ascii=False))
PYEOF
fi

exit 0
