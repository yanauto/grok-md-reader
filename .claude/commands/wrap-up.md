---
description: 完整收尾——proj now/log、操作晋升、工程日文件、可选 ADR/kb。用户显式调用或口头结束经确认后执行。
---

执行收尾（不要省略步骤）。  
**控制面**（vitals）：仪表盘 now + 分层事件 log。  
**内容面**（md）：地图/手册/playbooks/ADR/日文件。  
详见 vitals 设计：`控制面对齐工程记忆v5`（长步骤永不进库）。

## 1. 总结本场

- 做了什么（代码/设计/调试/运维）  
- 决策信号（「决定」「最终」「不要」…）  
- 卡住的事  
- 下一步  
- **是否首次打通或修正了可复跑路径**（部署/回灌/联调/装机…）

## 2. 更新 `vitals proj now`（瘦身骨架 · 配合 vitals 工单）

**禁止**把本场流水账塞进 `--set`。固定骨架：

```bash
vitals proj now grok-md-reader \
  --set "状态: <≤2 句现行能力/环境>；卡住: <无|具体阻塞>" \
  --next "<动词+对象+验证1>; <动词+对象+验证2>"
```

- `--next` 最多 3 条；每条必须：**动词 + 对象 + 位置或验证**  
- 抽象 next（「继续优化」「完善」）= 没 next，必须重写  

## 3. 事件流

### 3.1 收尾摘要（必写）

```bash
vitals proj log grok-md-reader "<本场干了什么,1-2句>" --action session
```

### 3.2 显著进展（0-N）

阶段完成 / 关键 bug / 重构 / 新工程约定 才追加，带 `[FEATURE]`/`[FIX]`/`[REFACTOR]`/`[CONVENTION]`。

### 3.3 OPS 指针（有操作晋升时必写 · 控制面 `action=ops`）

本场若更新了地图入口 / playbook / 工程手册中的**可复跑路径**，额外：

```bash
vitals proj log grok-md-reader "<一句话动作> → <仓库内相对路径>" \
  --action ops \
  --report-ref "<同上相对路径>"
```

- CLI 会自动给 summary 补 `[OPS]` 前缀；箭头后的 path 可自动抽到 `report_ref`（显式 `--report-ref` 更稳）  
- 例：`… "scout-web 回灌 → docs/playbooks/scout-web-deploy.md" --action ops`  
- 查询：`vitals proj recent --project grok-md-reader --action ops --pretty`  
无新路径：不写本条。
## 4. 决策 → ADR（确认制）

列清单问用户沉淀哪些；确认后写入 `docs/decisions/NNNN-….md`，并：

```bash
vitals proj log grok-md-reader "ADR-NNNN: <标题>" --action decision
```

弱信号不进清单。

## 5. 操作晋升（v5 硬闸）

若本场**首次打通或修正**可复跑路径：

1. 更新 `docs/代码地图.md` 操作入口表（一行），和/或  
2. 新建/更新 `docs/playbooks/<动作>.md`，和/或  
3. 更新 `docs/工程手册.md` 相关节  
4. **立刻写 §3.3 `[OPS]` log**（指向上述文件）  

密钥只写 vault 指针。  
若无新路径：在日记里写「无新路径晋升」。

**禁止**只在 log/日记写「部署完成」而不留可复跑入口 + OPS 指针。
## 6. 跨项目知识池（确认制）

摸出**别的项目也用得上**的做法 → 问是否 `vitals kb add`（`--project grok-md-reader`，密钥不进池）。

## 7. 工程日记（一天一文件）

路径：`docs/sessions/YYYY-MM-DD.md`（UTC+8 当天）。

- 不存在 → 新建：`# YYYY-MM-DD · 日汇总` + 主题索引 + `## 场 1 · …`  
- 已存在 → 追加下一场，更新顶部索引  

场内短篇即可：主题 / 要点（含是否晋升）/ 下次。  
**无周记、无月记。**

## 8. 报告

```
✅ 收尾完成
- proj now：状态/卡住/next（已瘦身）
- 事件：session ± tag ± [OPS]
- 操作晋升：有（文件 + OPS log）/ 无
- 日记：docs/sessions/YYYY-MM-DD.md 第 N 场
- ADR：N 条 / 无
- kb：N 条 / 无
```

## 约束

- 不主动 git commit（用户要求才提交）  
- 不修改已有 ADR 文件  
- `--set`/`--next` 覆盖语义  
- vitals 失败如实报告，不装成功  
- `/checkpoint` 已废止，本命令是唯一收尾入口  
