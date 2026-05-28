---
name: java-lsp-trace
description: Java LSP 污点追踪与信任链审计。当需要通过 LSP 展开自定义校验方法、追踪跨文件调用链、分析属性污染时加载。Use when performing LSP-based taint analysis, tracing cross-file call graphs, expanding custom validation methods, or tracking attribute pollution chains.
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Phase 4: LSP 污点追踪与信任链深度审计

## 输入

- 项目根路径
- 追踪目标列表（来自 Phase 2/3 的 FAIL 断言，或 Phase 5 的回溯请求）
- 熔断状态（来自 Phase 2/3）

## 输出

- Phase-Result JSON（符合 `shared-contracts.md` 协议）

## 符号与隐式共享上下文断言（L1-L5）

| 断言 | 检查项 | 说明 |
|------|--------|------|
| L1 | 禁止黑盒猜测 | 遇到非标准的自定义校验方法，必须使用 `textDocument/definition` 强制展开其底层判定逻辑 |
| L1.1 | LSP深度熔断 | 执行 LSP 跳转时，强制定义最大跳转深度 MAX_LSP_DEPTH: 3。若3层内未到达原子判定逻辑，则触发"断言失败熔断" |
| L2 | 跨文件符号追踪 | 提炼出完整的跨文件、跨方法调用链条（Call Graph） |
| L3 | 原子化追踪记录 | 必须单行、无省略地记录符号流向表格 |
| L4 | 信任链属性污染 | 追踪所有隐式共享上下文的污染链路：`request.setAttribute()` / `session.setAttribute()` / `ServletContext.setAttribute()` / `ThreadLocal.set()` / Spring `RequestContextHolder` 的属性传递 |
| L5 | 最终判定断言 | 结合前面各阶段的绕过可能，给出闭环的复合威胁链路判定 |

## 执行流程

### Step 1: 确定追踪目标

```
targets = []
if input is Backtrack-Request:
    targets.append(input.target_method)
else:
    for each FAIL assertion in Phase 2/3 results:
        targets.append(assertion.evidence_location)
```

### Step 2: LSP 符号展开（L1, L1.1, L2）

```
for each target in targets:
    depth = 0
    current = target
    while depth < MAX_LSP_DEPTH(3):
        definition = LSP goToDefinition(current)
        if definition is atomic logic:
            record trace
            break
        current = definition
        depth += 1
    if depth >= MAX_LSP_DEPTH:
        trigger ERR-LSP-DEPTH
        record lsp_unresolved: true
```

### Step 3: 调用链构建（L2, L3）

```
for each target:
    callers = LSP incomingCalls(target)
    callees = LSP outgoingCalls(target)
    build call graph
    record atomic trace table
```

### Step 4: 信任链属性污染追踪（L4）

```
scan for implicit shared context APIs:
    - request.setAttribute()
    - session.setAttribute()
    - ServletContext.setAttribute()
    - ThreadLocal.set()
    - RequestContextHolder

for each pollution point:
    trace attribute flow
    record pollution chain
```

### Step 5: 最终判定（L5）

```
combine Phase 2/3 bypass findings with LSP traces
generate composite threat chain
output final assertion
```

## 强制输出模板

> 详细输出模板见 [`references/phase4-lsp-output.md`](references/phase4-lsp-output.md)

## 输出示例

```json
{
  "phase": "Phase 4",
  "assertions": [
    {
      "id": "L1",
      "target": "AuthFilter.checkPermission",
      "status": "PASS",
      "evidence": "AuthFilter.java:78",
      "detail": "LSP展开确认：checkPermission() 内部使用白名单匹配"
    },
    {
      "id": "L4",
      "target": "request.setAttribute(\"userId\")",
      "status": "FAIL",
      "evidence": "LoginController.java:45",
      "detail": "userId 来自 request.getParameter() 直接写入 attribute，下游 Filter 信任该属性"
    }
  ],
  "circuit_breakers": [],
  "trace_chains": [
    {
      "chain_id": "TC-001",
      "path": "LoginController.doLogin → request.setAttribute(\"userId\") → AuthFilter.getAttribute(\"userId\") → checkPermission",
      "pollution_type": "request_attribute"
    }
  ]
}
```
