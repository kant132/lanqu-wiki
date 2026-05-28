---
name: java-filter-audit
description: Java Filter 安全审计。当需要审计 javax.servlet.Filter 或 jakarta.servlet.Filter 的路径匹配绕过、净化缺陷时加载。Use when auditing Java servlet filters for path matching bypass, sanitization flaws, or security pointer analysis.
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Phase 2: Filter 核心审计阶段

## 输入

- Asset-Inventory JSON（来自 Phase 1 的 filters 列表）
- 项目根路径

## 输出

- Phase-Result JSON（符合 `shared-contracts.md` 协议）

## 7类安全指针（P1-P7）

针对 Phase 1 建立的所有 Filter 资产，必须逐一断言以下安全指针：

| 指针 | 检查项 | 说明 |
|------|--------|------|
| P1 | Source提取 | 是否使用了 `getRequestURI()` 或 `getServletPath()`？ |
| P2 | LSP交叉引用 | URI 变量是否通过 LSP 跳转传递至外部判断方法？ |
| P3 | 安全净化 | 匹配前是否显式调用路径规范化算子（如 `.normalize()` 或解码）？ |
| P4 | 前缀/包含Sink匹配 | 是否使用了无边界闭合的 `.startsWith()` 或 `.contains()`？ |
| P5 | 新型Sink边界 | 是否使用了存在换行绕过的 `.matches(regex)` 或存在矩阵变量/后缀绕过风险的 `.endsWith()`？ |
| P6 | 大小写敏感度 | 是否因 `.toLowerCase()` 或 `equalsIgnoreCase` 引入特定语系（如土耳其I缺陷）或宿主环境解析差异？ |
| P7 | 容器解析差异 | 是否对分号参数（`;`）和多重斜杠（`//`）执行了主动清洗？ |

## 执行流程

### Step 1: 加载 Filter 清单

从 Asset-Inventory 提取 filters 列表，若为空则返回 N/A。

### Step 2: 逐 Filter 断言

对每个 Filter 执行 P1-P7 检查：

```
for each filter in inventory.filters:
    read filter source file
    for each pointer in [P1, P2, P3, P4, P5, P6, P7]:
        evaluate pointer
        record assertion result
```

### Step 3: LSP 交叉引用（P2）

对 P1 发现的 URI 变量，使用 LSP `findReferences` 追踪其传递路径。

### Step 4: 熔断标记

若任一 Filter 的 P4/P5/P7 为 FAIL，生成 `filter_bypassed` 熔断标记。

## 强制输出模板

> 详细输出模板见 [`references/phase2-filter-output.md`](references/phase2-filter-output.md)

## 输出示例

```json
{
  "phase": "Phase 2",
  "assertions": [
    {
      "id": "P1",
      "target": "FILTER-001",
      "status": "PASS",
      "evidence": "AuthFilter.java:32",
      "detail": "使用 getRequestURI() 提取路径"
    },
    {
      "id": "P4",
      "target": "FILTER-001",
      "status": "FAIL",
      "evidence": "AuthFilter.java:45",
      "detail": "使用 .startsWith(\"/api\") 无边界闭合，可被 /api../admin 绕过"
    }
  ],
  "circuit_breakers": [
    {
      "type": "filter_bypassed",
      "target": "FILTER-001",
      "affected_paths": ["/api/*"]
    }
  ]
}
```
