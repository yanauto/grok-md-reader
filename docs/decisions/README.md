# 决策记录（ADR）

> Architecture Decision Records。**不可变** append-only 仓库。

## 约定

1. **编号严格递增**：`0001-`, `0002-`, `0003-`...（零填充 4 位）
2. **一旦生成不可修改**：除了「状态」段可以从 Accepted 改为 Superseded
3. **废弃方式**：新建 ADR-NNNN 标注 `Supersedes ADR-MMMM`，**旧 ADR 保留**并改状态为 `Superseded by NNNN`
4. **绝不删除任何 ADR**，即使错误的决策——错误的决策也是历史

## 命名

`NNNN-{slug}.md`

- `NNNN`：4 位编号
- `{slug}`：标题转 kebab-case，不超过 6 个英文词
- 例：`0001-use-postgres.md` / `0002-prompt-files-separate-from-code.md`

## 模板

由 `/decision` 命令使用：

```markdown
# ADR-NNNN: [标题]

**日期**：YYYY-MM-DD（UTC+8）
**状态**：Accepted

## 背景（Context）

为什么需要这个决策——什么问题、什么约束、什么场景。

## 决策（Decision）

明确的「我们决定 X」——具体到能执行。

## 理由（Rationale）

为什么是 X 而不是 Y / Z。
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

## 命令

- `/decision` — 生成新 ADR（自动取下一编号、检查不重复、写入索引）

## 状态值

只允许这两个：
- `Accepted` — 当前有效
- `Superseded by NNNN` — 被新 ADR 替代

不要用 `Draft` / `Proposed` / `Rejected` —— 这是「决策记录」不是「提案」。讨论中的方案留在对话里聊透,拍板了才进 ADR。
