# Phase 2 输出模板

## FILTER_AUDIT

```markdown
[FILTER_AUDIT]
_audit_id: "F_XXX"
_audit_target: "ClassName"
_assertions_applied: ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]

### [H-FI-XXX] Filter 漏洞名称
* **组件位置**: `Servlet Filter` | `FileName:Line`
* **漏洞类型**: 详细分类
* **强制检查结果**:

| 指针 | 检查项 | 结果 | 置信度 | 证据 |
|------|--------|------|--------|------|
| P1 | Source提取 | PASS/FAIL/FALSE_POSITIVE/N/A | HIGH/MEDIUM/LOW | 代码片段 |
| P2 | LSP交叉引用 | PASS/FAIL/FALSE_POSITIVE/N/A | HIGH/MEDIUM/LOW | 代码片段 |
| P3 | 安全净化 | PASS/FAIL/FALSE_POSITIVE/N/A | HIGH/MEDIUM/LOW | 代码片段 |
| P4 | 前缀/包含Sink匹配 | PASS/FAIL/FALSE_POSITIVE/N/A | HIGH/MEDIUM/LOW | 代码片段 |
| P5 | 新型Sink边界 | PASS/FAIL/FALSE_POSITIVE/N/A | HIGH/MEDIUM/LOW | 代码片段 |
| P6 | 大小写敏感度 | PASS/FAIL/FALSE_POSITIVE/N/A | HIGH/MEDIUM/LOW | 代码片段 |
| P7 | 容器解析差异 | PASS/FAIL/FALSE_POSITIVE/N/A | HIGH/MEDIUM/LOW | 代码片段 |

> **结果状态说明**: PASS=安全 / FAIL=确认存在缺陷 / FALSE_POSITIVE=表面风险但有补偿控制（需说明理由）/ N/A=不适用
> **置信度说明**: HIGH=LSP 追踪到原子判定 / MEDIUM=静态分析推断 / LOW=框架行为推测

#### 1. 基于 LSP 捕获的污点流 (LSP Taint Flow)

```
[Source] request.getRequestURI() ──> [Operator] 变换 ──> [Sink] 匹配函数
```

#### 2. 核心缺陷与 PoC 矩阵

| 缺陷类型 | 触发条件 | PoC Payload |
|----------|----------|-------------|
| 类型1 | 条件描述 | `payload` |
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `_audit_id` | String | 审计ID，格式F_XXX |
| `_audit_target` | String | 目标类名 |
| `_assertions_applied` | Array[String] | 已应用的断言代码列表 |

## 示例

```markdown
[FILTER_AUDIT]
_audit_id: "F_001"
_audit_target: "PathValidationFilter"
_assertions_applied: ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]

### [H-FI-001] Filter 路径匹配绕过
* **组件位置**: `Servlet Filter` | `PathValidationFilter.java:45`
* **漏洞类型**: 路径匹配绕过 / 矩阵变量注入
* **强制检查结果**:

| 指针 | 检查项 | 结果 | 置信度 | 证据 |
|------|--------|------|--------|------|
| P1 | Source提取 | PASS | HIGH | getRequestURI() |
| P2 | LSP交叉引用 | FAIL | HIGH | URI变量传递至externalCheck() |
| P3 | 安全净化 | FAIL | HIGH | 未调用normalize() |
| P4 | 前缀/包含Sink匹配 | FAIL | HIGH | 使用.startsWith("/api") |
| P5 | 新型Sink边界 | FAIL | HIGH | 使用.endsWith(".js") |
| P6 | 大小写敏感度 | PASS | MEDIUM | 无大小写转换 |
| P7 | 容器解析差异 | FAIL | HIGH | 未清洗分号参数 |

#### 1. 基于 LSP 捕获的污点流 (LSP Taint Flow)

```
request.getRequestURI() ──> String path = uri ──> if (path.startsWith("/api")) ──> chain.doFilter()
```

#### 2. 核心缺陷与 PoC 矩阵

| 缺陷类型 | 触发条件 | PoC Payload |
|----------|----------|-------------|
| 矩阵变量注入 | 分号被容器保留 | `/api/v2/privilege/dump;.js` |
| 多重斜杠绕过 | //被规范化为/ | `/api//v2/privilege/dump` |
```