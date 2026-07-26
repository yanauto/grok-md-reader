---
description: 阶段性 checkpoint——只更新项目状态(vitals proj now)，不写事件流不生成 ADR。临时暂停用。
---

轻量版收尾。适用场景：干到一半要切去做别的，下次还会回来继续这个对话脉络。

执行：

## 1. 更新项目状态

```bash
vitals proj now grok-md-reader --set "<到目前为止做到哪>" --next "<接下来的具体下一步>"
```

`--next` 质量要求同 /wrap-up（动词 + 对象 + 位置/验证）。

## 2. 不动其他东西

- ❌ 不写 `proj log` 事件（那是 wrap-up 的事）
- ❌ 不生成 ADR
- ❌ 不动 feature

## 3. 报告

```
✅ checkpoint 已存
- 状态: [一句话说现在在哪]
- 下一步: [一句话]

可以放心切走，下次回来 SessionStart 会自动注入（或手动 vitals proj now grok-md-reader --pretty）。
```

## 和 `/wrap-up` 的区别

| 维度 | `/checkpoint` | `/wrap-up` |
|---|---|---|
| 触发 | 显式 | 触发短语经确认 / 显式 |
| 更新 proj now | ✅ | ✅ |
| 写 proj log 事件 | ❌ | ✅（session 必写） |
| 检测 ADR | ❌ | ✅ |
| 适用 | 临时暂停 | 完整结束 |
