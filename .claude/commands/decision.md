---
description: 沉淀单条决策为 ADR（不可变 append-only）。文件名编号严格递增。
---

把一个架构 / 设计 / 工程决策沉淀成 ADR（Architecture Decision Record）。

## 1. 取下一个编号

读 `docs/decisions/` 目录，扫所有形如 `NNNN-*.md` 的文件：
- 取最大数字 + 1
- 零填充 4 位（如 `0003`）
- 如果还没有任何 ADR，从 `0001` 开始

## 2. 问用户

如果用户在调用 `/decision` 时没说清楚，问：

> 决策内容是什么？我需要：
> 1. 标题（一句话，10 字内）
> 2. 背景（为什么需要这个决策）
> 3. 决策（明确的「我们决定 X」）
> 4. 理由（为什么是 X 而不是 Y / Z）
> 5. 影响（短期 / 长期 / 风险）

如果上下文已经有足够信息，直接基于上下文生成草稿，然后让用户确认。

## 3. 生成文件

文件名：`docs/decisions/NNNN-{slug}.md`
- `NNNN`：4 位编号
- `{slug}`：标题转 kebab-case，不超过 6 个英文词或对应中文

模板：

```markdown
# ADR-NNNN: [标题]

**日期**：YYYY-MM-DD（UTC+8）
**状态**：Accepted

## 背景（Context）

[为什么需要这个决策——什么问题、什么约束、什么场景]

## 决策（Decision）

[明确的「我们决定 X」——具体到能执行]

## 理由（Rationale）

[为什么是 X 而不是 Y / Z]
- 选项 A：（被否决原因）
- 选项 B：（被否决原因）
- 选项 C（采纳）：（采纳原因）

## 影响（Consequences）

### 短期
- ...

### 长期
- ...

### 潜在风险
- ...

## 相关

- 关联 feature：[feature-name]（如有）
- 相关 ADR：[ADR-NNNN]（如有）
```

## 4. 不可变检查

**写文件前必检**：
- `docs/decisions/NNNN-*.md` 已存在 → **报错，绝不覆盖**。提示用户改标题，或确认这是要补充已有 ADR（这时建议新建 ADR 标 `Supersedes ADR-NNNN`）

**绝对不允许的事**：
- 覆盖已有 ADR
- 删除已有 ADR
- 修改已有 ADR 的「决策」「理由」段（只能改「状态」段为 `Superseded by NNNN`）

## 5. 写决策指针事件

正文在 md,库里只存指针(跨项目可见,`ls docs/decisions/` 即索引,无需另维护 INDEX)：

```bash
vitals proj log grok-md-reader "ADR-NNNN: <标题一句话>" --action decision
```

## 6. 报告

```
✅ ADR-NNNN 已沉淀
- 文件：docs/decisions/NNNN-{slug}.md
- 标题：[标题]
- 状态：Accepted（永久不可变）

废弃方式：日后新建 ADR-MMMM 标注「Supersedes ADR-NNNN」，旧 ADR 状态改为「Superseded by MMMM」，永不删除。
```

## 约束

- ✅ 编号严格递增，不复用
- ✅ 文件名不允许覆盖
- ✅ 状态除了 Accepted / Superseded 不要其他值
- ❌ 不主动 git commit（用户明确要求才提交）
