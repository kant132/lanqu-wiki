# Phase 2 输出模板

## FILTER_CHAIN_ORDER

```markdown
[FILTER_CHAIN_ORDER]
_generated_at: "TIMESTAMP"

### Filter 执行链顺序

| 执行顺序 | Filter ID | 类名 | URL 模式 | Order 值 | 注册方式 | Dispatcher 类型 | 是否短路 |
|----------|-----------|------|----------|----------|----------|----------------|----------|
| 1 | FILTER-001 | AuthFilter | /api/* | 1 | FilterRegistrationBean | REQUEST, FORWARD | 否 |
| 2 | FILTER-002 | RateLimitFilter | /* | 2 | @WebFilter | REQUEST | 否 |
| 3 | FILTER-003 | PathValidationFilter | /api/* | 3 | FilterRegistrationBean | REQUEST | 否 |

### 执行链可视化

```
Request → Filter1(order=1, /api/*, FilterRegistrationBean) → Filter2(order=2, /*, @WebFilter) → Filter3(order=3, /api/*) → Servlet
```
```

## FILTER_CLASS_AUDIT (第一层：Filter 类代码审计)

```markdown
[FILTER_AUDIT]
_audit_id: "F_XXX"
_audit_target: "ClassName"
_assertions_applied: ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]
_execution_order: INT
_reachability: "REACHABLE|PARTIALLY_REACHABLE|UNREACHABLE"
_severity_adjusted: "CRITICAL|HIGH|MEDIUM|LOW|INFO"

### [H-FI-XXX] Filter 漏洞名称
* **组件位置**: `Servlet Filter` | `FileName:Line`
* **漏洞类型**: 详细分类
* **执行顺序**: 第 N 个执行
* **可达性评估**: REACHABLE / PARTIALLY_REACHABLE / UNREACHABLE
* **可达性理由**: 说明为何可达/不可达
* **原始严重度**: HIGH
* **调整后严重度**: MEDIUM / INFO
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
> **可达性说明**: REACHABLE=漏洞可被实际触发 / PARTIALLY_REACHABLE=部分场景可达 / UNREACHABLE=被前置Filter拦截或后置Filter补偿

#### 1. 基于 LSP 捕获的污点流 (LSP Taint Flow)

```
[Source] request.getRequestURI() ──> [Operator] 变换 ──> [Sink] 匹配函数
```

#### 2. 核心缺陷与 PoC 矩阵

| 缺陷类型 | 触发条件 | PoC Payload | 可达性 |
|----------|----------|-------------|--------|
| 类型1 | 条件描述 | `payload` | REACHABLE/UNREACHABLE |

#### 3. 前置/后置 Filter 影响分析

| 相关 Filter | 执行顺序 | 影响类型 | 说明 |
|-------------|----------|----------|------|
| Filter2 | 前置(order=2) | 拦截 | Filter2 在相同 URL 模式上执行认证检查，阻止未认证请求到达本 Filter |
| Filter3 | 后置(order=4) | 补偿 | Filter3 执行额外的路径规范化，补偿本 Filter 的绕过风险 |
```

## FILTER_CONFIG_AUDIT (第二层：Filter 注册配置审计)

```markdown
[FILTER_CONFIG_AUDIT]
_audit_id: "FC_XXX"
_audit_target: "FilterRegistrationBean / @WebFilter / web.xml"
_registration_source: "FilterRegistrationBean|@WebFilter|web.xml|SecurityFilterChain内置"
_assertions_applied: ["FC1", "FC2", "FC3", "FC4", "FC5", "FC6"]

### [H-FC-XXX] Filter 注册配置缺陷

* **注册方式**: FilterRegistrationBean / @WebFilter / web.xml
* **配置位置**: `FileName:Line`
* **关联 Filter**: FILTER-XXX

| 指针 | 检查项 | 结果 | 证据 | 详情 |
|------|--------|------|------|------|
| FC1 | 注册方式一致性 | PASS/FAIL | 代码片段 | 是否多处注册导致冲突 |
| FC2 | URL模式覆盖完整性 | PASS/FAIL | 代码片段 | URL 模式是否覆盖所有需保护路径 |
| FC3 | Dispatcher类型 | PASS/FAIL | 代码片段 | 是否包含 FORWARD/INCLUDE/ASYNC |
| FC4 | 初始化参数安全 | PASS/FAIL | 代码片段 | init-param 是否有硬编码密钥/白名单过宽 |
| FC5 | Order值冲突 | PASS/FAIL | 代码片段 | 多个 Filter order 值是否冲突 |
| FC6 | 条件注册 | PASS/FAIL | 代码片段 | @ConditionalOnProperty 是否导致某些环境不加载 |
```

## SECURITY_FILTER_CHAIN_AUDIT (第三层：SecurityFilterChain 配置审计)

```markdown
[SECURITY_FILTER_CHAIN_AUDIT]
_audit_id: "SC_XXX"
_audit_target: "SecurityFilterChain Bean 名称"
_config_class: "配置类全限定名"
_assertions_applied: ["SC1", "SC2", "SC3", "SC4", "SC5", "SC6", "SC7", "SC8", "SC9", "SC10"]

### [H-SC-XXX] SecurityFilterChain 配置缺陷

* **配置类**: `WebSecurityConfig.java`
* **Bean 方法**: `filterChain():Line`
* **securityMatcher**: 匹配的 URL 模式

| 指针 | 检查项 | 结果 | 证据 | 详情 | 可达性 | 调整后严重度 |
|------|--------|------|------|------|--------|-------------|
| SC1 | CSRF配置 | PASS/FAIL | 代码片段 | csrf.disable() 或配置详情 | REACHABLE/... | HIGH/... |
| SC2 | 认证路径配置 | PASS/FAIL | 代码片段 | permitAll 路径列表 | REACHABLE/... | HIGH/... |
| SC3 | 密码编码器 | PASS/FAIL | 代码片段 | PasswordEncoder 类型 | REACHABLE/... | HIGH/... |
| SC4 | CORS配置 | PASS/FAIL/N/A | 代码片段 | allowedOrigins/Methods | REACHABLE/... | MEDIUM/... |
| SC5 | 会话管理 | PASS/FAIL | 代码片段 | SessionFixation/最大会话数 | REACHABLE/... | MEDIUM/... |
| SC6 | HTTP安全头 | PASS/FAIL | 代码片段 | headers.disable() 或配置详情 | REACHABLE/... | HIGH/... |
| SC7 | 认证入口点 | PASS/FAIL | 代码片段 | EntryPoint 是否泄露信息 | REACHABLE/... | LOW/... |
| SC8 | OAuth2/OIDC配置 | PASS/FAIL/N/A | 代码片段 | redirect_uri/Token验证 | REACHABLE/... | MEDIUM/... |
| SC9 | Remember-Me | PASS/FAIL/N/A | 代码片段 | Token策略/密钥 | REACHABLE/... | MEDIUM/... |
| SC10 | 多SecurityFilterChain | PASS/FAIL/N/A | 代码片段 | @Order + securityMatcher 分层 | REACHABLE/... | HIGH/... |

#### permitAll 路径与 API 清单交叉验证

| permitAll 路径 | 匹配的 API 端点 | 是否需要认证 | 风险评估 |
|----------------|----------------|-------------|----------|
| /actuator/** | /actuator/env, /actuator/configprops | 否（permitAll） | HIGH: 敏感配置暴露 |
| /registration | GET /registration | 否（设计如此） | LOW: 注册页面 |
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `_audit_id` | String | 审计ID，格式F_XXX |
| `_audit_target` | String | 目标类名 |
| `_assertions_applied` | Array[String] | 已应用的断言代码列表 |

## 示例

```markdown
[FILTER_CHAIN_ORDER]
_generated_at: "2026-05-29T10:00:00Z"

### Filter 执行链顺序

| 执行顺序 | Filter ID | 类名 | URL 模式 | Order 值 | 是否短路 |
|----------|-----------|------|----------|----------|----------|
| 1 | FILTER-001 | AuthFilter | /api/* | 1 | 否 |
| 2 | FILTER-002 | RateLimitFilter | /* | 2 | 否 |
| 3 | FILTER-003 | PathValidationFilter | /api/* | 3 | 否 |

### 执行链可视化

```
Request → AuthFilter(order=1, /api/*) → RateLimitFilter(order=2, /*) → PathValidationFilter(order=3, /api/*) → Servlet
```

[FILTER_AUDIT]
_audit_id: "F_001"
_audit_target: "PathValidationFilter"
_assertions_applied: ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]
_execution_order: 3
_reachability: "PARTIALLY_REACHABLE"
_severity_adjusted: "MEDIUM"

### [H-FI-001] Filter 路径匹配绕过
* **组件位置**: `Servlet Filter` | `PathValidationFilter.java:45`
* **漏洞类型**: 路径匹配绕过 / 矩阵变量注入
* **执行顺序**: 第 3 个执行
* **可达性评估**: PARTIALLY_REACHABLE
* **可达性理由**: AuthFilter(order=1) 在 /api/* 路径上执行认证检查，未认证请求被拦截；但已认证用户仍可触发此绕过漏洞
* **原始严重度**: HIGH
* **调整后严重度**: MEDIUM
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

| 缺陷类型 | 触发条件 | PoC Payload | 可达性 |
|----------|----------|-------------|--------|
| 矩阵变量注入 | 分号被容器保留 + 已认证 | `/api/v2/privilege/dump;.js` | PARTIALLY_REACHABLE |
| 多重斜杠绕过 | //被规范化为/ + 已认证 | `/api//v2/privilege/dump` | PARTIALLY_REACHABLE |

#### 3. 前置/后置 Filter 影响分析

| 相关 Filter | 执行顺序 | 影响类型 | 说明 |
|-------------|----------|----------|------|
| AuthFilter | 前置(order=1) | 部分拦截 | AuthFilter 拦截未认证请求，但已认证用户仍可到达本 Filter |
| RateLimitFilter | 前置(order=2) | 无影响 | 仅做频率限制，不影响漏洞可达性 |
```