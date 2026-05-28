# Phase 4 输出模板

## LSP_TAINT_TRACE

```markdown
[LSP_TAINT_TRACE]
_trace_id: "TRACE_XXX"
_root_filter: "ClassName"
_shared_context_key: "request.setAttribute(KEY)"

### 追踪链路概览

| 步骤 | 类型 | 位置 | 操作 | LSP结果 |
|------|------|------|------|----------|
| 1 | Source | FileName:Line | 获取请求路径 | request.getRequestURI() |
| 2 | Propagate | FileName:Line | 路径赋值 | path = uri |
| 3 | Transform | FileName:Line | 字符串操作 | path.replace("//", "/") |
| 4 | Sink | FileName:Line | 路径匹配 | path.startsWith(target) |

### 1. 数据流向与符号追踪 (LSP References & Attributes Trace)

```
[Step 1] request.getRequestURI() @ SourceFile:20
    │
    └──LSP Definition──> HttpServletRequest.getRequestURI()

[Step 2] String path = uri @ MiddleFile:25
    │
    └──LSP References──> path变量被引用 @ MiddleFile:28

[Step 3] path.replace("//", "/") @ MiddleFile:28
    │
    └──LSP Definition──> String.replace()实现

[Step 4] path.startsWith(target) @ SinkFile:35
    │
    └──LSP Definition──> String.startsWith()实现
```

### 2. 属性污染追踪 (Attribute Pollution)

| 操作 | 位置 | Key | Value来源 | 信任方 |
|------|------|-----|----------|--------|
| setAttribute | FilterA:30 | `auth_status` | FilterA | InterceptorB |
| getAttribute | InterceptorB:45 | `auth_status` | FilterA | 鉴权逻辑 |

### 3. 威胁判定

> **复合攻击链路**: 详细描述攻击者如何利用前级 Filter 匹配绕过污染 Attributes，进而穿透后级 Interceptor 的深度闭环。

| 攻击阶段 | 组件 | 操作 | 结果 |
|----------|------|------|------|
| 1 | FilterA | 路径匹配缺陷 | 恶意路径被放行 |
| 2 | FilterA | setAttribute("auth_status", "true") | 属性污染 |
| 3 | InterceptorB | getAttribute("auth_status") | 信任污染值 |
| 4 | InterceptorB | 鉴权通过 | 越权访问 |
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `_trace_id` | String | 追踪ID，格式TRACE_XXX |
| `_root_filter` | String | 根Filter类名 |
| `_shared_context_key` | String | 共享上下文Key |

## 示例

```markdown
[LSP_TAINT_TRACE]
_trace_id: "TRACE_001"
_root_filter: "GatewaySecurityFilter"
_shared_context_key: "request.setAttribute(X-Gate-Pass)"

### 追踪链路概览

| 步骤 | 类型 | 位置 | 操作 | LSP结果 |
|------|------|------|------|----------|
| 1 | Source | GatewayFilter:22 | 获取请求路径 | request.getRequestURI() |
| 2 | Propagate | GatewayFilter:25 | 路径赋值 | uri = request.getRequestURI() |
| 3 | Transform | GatewayFilter:28 | 错误的安全判断 | isStaticResource(uri) |
| 4 | Sink | GatewayFilter:30 | 设置污染属性 | request.setAttribute("X-Gate-Pass", "true") |

### 1. 数据流向与符号追踪 (LSP References & Attributes Trace)

```
[Step 1] request.getRequestURI() @ GatewayFilter:22
    │
    └──LSP Definition──> HttpServletRequest.getRequestURI()

[Step 2] uri = request.getRequestURI() @ GatewayFilter:25
    │
    └──LSP References──> uri参数传递 @ GatewayFilter:28

[Step 3] isStaticResource(uri) @ GatewayFilter:28
    │
    └──LSP Definition──> private boolean isStaticResource(String path) {
                              return path.endsWith(".js") || path.endsWith(".css");
                          }  // ← 错误判断逻辑

[Step 4] request.setAttribute("X-Gate-Pass", "true") @ GatewayFilter:30
    │
    └──LSP References──> 属性被设置 @ InterceptorB:45
```

### 2. 属性污染追踪 (Attribute Pollution)

| 操作 | 位置 | Key | Value来源 | 信任方 |
|------|------|-----|----------|--------|
| setAttribute | GatewayFilter:30 | `X-Gate-Pass` | GatewayFilter | RoutingAuthInterceptor |
| getAttribute | InterceptorB:45 | `X-Gate-Pass` | GatewayFilter | 鉴权逻辑 |

### 3. 威胁判定

> **复合攻击链路**: GatewayFilter使用错误的isStaticResource()判断（仅检查.js/.css后缀），攻击者可通过`/api/v2/privilege/dump;.js`绕过路径匹配。绕过成功后设置污染属性X-Gate-Pass=true，后续IntercepterB读取该属性认为已鉴权，导致越权访问。

| 攻击阶段 | 组件 | 操作 | 结果 |
|----------|------|------|------|
| 1 | GatewayFilter | 路径判断错误 | `/api/v2/privilege/dump;.js` 被放行 |
| 2 | GatewayFilter | setAttribute("X-Gate-Pass", "true") | 属性污染 |
| 3 | InterceptorB | getAttribute("X-Gate-Pass") | 读取污染值 |
| 4 | InterceptorB | 鉴权通过（误判） | 越权访问 |
```