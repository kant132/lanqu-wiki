---
name: java-filter-audit
description: Java Filter 与安全配置审计。当需要审计 javax.servlet.Filter/jakarta.servlet.Filter 的路径匹配绕过、净化缺陷，以及 Filter 注册配置、SecurityFilterChain 配置、@Configuration 安全 Bean 配置时加载。Use when auditing Java servlet filters, filter registration, SecurityFilterChain configuration, or security-related @Configuration beans.
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Phase 2: Filter 与安全配置审计阶段

## 输出语言规则

所有报告内容必须使用中文输出。标题、描述、分析文字、表头、结论均使用中文。以下内容保持英文：代码片段、文件路径、类名、方法名、技术状态码（PASS/FAIL/N/A、REACHABLE/UNREACHABLE）。

## 输入

- Asset-Inventory JSON（来自 Phase 1 的 filters + security_configs 列表）
- 项目根路径

## 输出

- Phase-Result JSON（符合 `shared-contracts.md` 协议）

## 审计范围（三层）

### 第一层：Filter 类代码审计（P1-P7）

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

### 第二层：Filter 注册与配置审计（FC1-FC6）

针对 Filter 的注册方式和配置参数进行审计：

| 指针 | 检查项 | 说明 |
|------|--------|------|
| FC1 | 注册方式一致性 | Filter 是否同时在多处注册（@WebFilter + FilterRegistrationBean + web.xml），导致执行多次或冲突？ |
| FC2 | URL 模式覆盖完整性 | FilterRegistrationBean.setUrlPatterns() / @WebFilter.urlPatterns() 是否覆盖了所有需要保护的路径？是否存在遗漏？ |
| FC3 | Dispatcher 类型 | Filter 是否配置了正确的 DispatcherType（REQUEST/FORWARD/INCLUDE/ERROR/ASYNC）？仅配 REQUEST 时 FORWARD 请求可绕过 |
| FC4 | 初始化参数安全 | FilterRegistrationBean.addInitParameter() / web.xml <init-param> 中是否有硬编码密钥、白名单路径过宽等问题？ |
| FC5 | Order 值冲突 | 多个 Filter 的 order 值是否冲突？冲突时执行顺序不确定可能导致安全逻辑被跳过 |
| FC6 | 条件注册 | @ConditionalOnProperty / @Profile 条件是否导致安全 Filter 在某些环境下不加载？ |

### 第三层：SecurityFilterChain 配置审计（SC1-SC10）

针对 SecurityFilterChain Bean 的配置进行深度审计：

| 指针 | 检查项 | 说明 |
|------|--------|------|
| SC1 | CSRF 配置 | csrf.disable() 是否合理？若禁用，是否有补偿控制（如自定义 Token 校验）？ |
| SC2 | 认证路径配置 | authorizeHttpRequests/antMatchers 的 permitAll 路径是否过宽？是否遗漏了需要保护的路径？ |
| SC3 | 密码编码器 | PasswordEncoder Bean 是否安全？NoOpPasswordEncoder 明文存储，BCrypt 强度是否足够？ |
| SC4 | CORS 配置 | CorsConfigurationSource 是否允许了不受信任的 Origin？是否允许 Credentials + 通配符 Origin？ |
| SC5 | 会话管理 | sessionManagement 配置是否安全？SessionFixation 防护、最大会话数、会话超时是否配置？ |
| SC6 | HTTP 安全头 | headers() 是否被禁用？X-Frame-Options、CSP、X-Content-Type-Options 是否配置？ |
| SC7 | 认证入口点 | AuthenticationEntryPoint 和 AccessDeniedHandler 是否泄露敏感信息（如返回详细错误消息）？ |
| SC8 | OAuth2/OIDC 配置 | OAuth2 客户端配置是否安全？redirect_uri 是否可被操纵？Token 验证是否完整？ |
| SC9 | Remember-Me | rememberMe 配置是否使用安全的 Token 策略？密钥是否硬编码？ |
| SC10 | 多 SecurityFilterChain | 多个 SecurityFilterChain 的 @Order 和 securityMatcher 是否正确分层？是否存在路径重叠或遗漏？ |

## 执行流程

### Step 1: 加载 Filter 与安全配置清单

```
从 Asset-Inventory 提取：
  - filters 列表（自定义 Filter 类）
  - security_configs 列表（SecurityFilterChain 配置类）
  - filter_registrations 列表（FilterRegistrationBean 注册）
  - 若三者均为空则返回 N/A
```

### Step 2: 执行顺序分析

```
提取所有 Filter 的执行顺序：
  - @WebFilter 注解的 urlPatterns 和 servletNames
  - FilterRegistrationBean 的 order 属性或 @Order 注解
  - web.xml 中 <filter-mapping> 的声明顺序
  - Spring Security FilterChain 中各 Filter 的固定顺序

输出 Filter 执行链：
  FilterChain = [Filter1(order=1) → Filter2(order=2) → ... → FilterN(order=N)]

对每个 Filter 记录：
  - 执行位置（第几个）
  - 覆盖的 URL 模式
  - Dispatcher 类型（REQUEST/FORWARD/INCLUDE/ERROR/ASYNC）
  - 是否短路（直接返回响应，不调用 chain.doFilter）
  - 注册方式（@WebFilter / FilterRegistrationBean / web.xml / SecurityFilterChain 内置）
```

### Step 3: 第一层 — 逐 Filter 类代码断言（P1-P7）

```
for each filter in inventory.filters:
    read filter source file
    for each pointer in [P1, P2, P3, P4, P5, P6, P7]:
        evaluate pointer
        record assertion result
```

### Step 4: 第二层 — Filter 注册与配置审计（FC1-FC6）

```
for each filter_registration in inventory.filter_registrations:
    read registration source (FilterRegistrationBean / @WebFilter / web.xml)
    for each pointer in [FC1, FC2, FC3, FC4, FC5, FC6]:
        evaluate pointer
        record assertion result

重点检查：
  - FilterRegistrationBean 的 setUrlPatterns / addUrlPatterns 覆盖范围
  - setDispatcherTypes 是否包含 FORWARD/INCLUDE（防止 forward 绕过）
  - addInitParameter 中是否有硬编码密钥或过宽白名单
  - @ConditionalOnProperty 条件是否导致安全 Filter 在某些 profile 下不加载
  - 多个 Filter 的 order 值是否冲突
```

### Step 5: 第三层 — SecurityFilterChain 配置审计（SC1-SC10）

```
for each security_config in inventory.security_configs:
    read SecurityFilterChain @Bean method
    for each pointer in [SC1..SC10]:
        evaluate pointer
        record assertion result

重点检查：
  - csrf() 是否 disable()，是否有补偿控制
  - authorizeHttpRequests() 的 permitAll 路径枚举与 API 清单交叉验证
  - PasswordEncoder @Bean 的类型（NoOpPasswordEncoder = FAIL）
  - CorsConfigurationSource @Bean 的 allowedOrigins/allowedMethods/allowCredentials
  - sessionManagement() 的 SessionFixation 防护、最大会话数
  - headers() 是否 disable()（X-Frame-Options、CSP 缺失）
  - 多个 SecurityFilterChain 的 @Order + securityMatcher 路径是否重叠或遗漏
  - OAuth2 客户端配置的 redirect_uri、Token 验证
  - AuthenticationEntryPoint 是否泄露敏感信息
```

### Step 5.5: 第四层 — SecurityFilterChain 配置安全语义深度审计（SC-DEEP）

```
核心思想:
  SC1-SC10 只检查配置项的值（如 csrf.disable()），但不分析配置对具体端点的安全影响。
  SC-DEEP 要求将每个配置决策追溯到其对所有受影响端点的实际安全影响。

加载深度审计清单: references/filter-config-deep.md

必须执行的深度检查:
  SC-DEEP-01: CSRF 禁用影响分析 — 枚举所有无 CSRF 防护的状态变更端点
  SC-DEEP-02: permitAll 路径深度分析 — 交叉匹配实际 API 端点，评估每个端点的敏感性
  SC-DEEP-03: 密码编码器链路分析 — 追踪密码从输入到存储的完整链路
  SC-DEEP-04: CORS 配置实际影响分析 — 哪些端点受 CORS 影响，是否携带认证
  SC-DEEP-05: 会话管理配置完整性分析 — 会话生命周期各阶段的安全检查
  SC-DEEP-06: 多 SecurityFilterChain 交互分析 — 路径重叠/遗漏检查
  SC-DEEP-07: OAuth2 配置安全语义分析 — 理解 OAuth2 流程每步的安全含义
  SC-DEEP-08: 错误处理信息泄露分析 — 认证/授权/异常错误消息是否泄露敏感信息

强制要求:
  - 每个 DEEP 检查项必须输出受影响的端点清单（不是仅输出配置值）
  - 每个 FAIL 必须关联到具体的端点和业务影响
  - 不得仅输出"csrf.disable()"就结束，必须分析禁用后哪些端点暴露于 CSRF 攻击
```

### Step 6: LSP 交叉引用（P2）

对 P1 发现的 URI 变量，使用 LSP `findReferences` 追踪其传递路径。

### Step 7: 漏洞可达性评估

```
对每个 FAIL 断言的漏洞，评估其实际可达性：

1. 前置拦截分析：
   - 检查该 Filter 之前的所有 Filter
   - 若前置 Filter 已拦截/拒绝相同请求模式，则漏洞不可达
   - 例如：Filter1 存在路径绕过漏洞，但 Filter2 在 Filter1 之前执行且已拦截该路径

2. 后置补偿分析：
   - 检查该 Filter 之后的所有 Filter
   - 若后置 Filter 能补偿该漏洞（如额外的认证检查），则风险降低

3. URL 模式交叉验证：
   - 漏洞影响的 URL 模式是否被其他 Filter 覆盖
   - 是否存在 URL 模式不重叠导致漏洞实际不可触发

4. 配置层补偿分析：
   - SecurityFilterChain 的 authorizeHttpRequests 是否已限制该路径
   - CORS 配置是否限制了跨域请求
   - 会话管理是否限制了未认证访问

可达性等级：
  - REACHABLE: 漏洞可被实际触发，无前置拦截或后置补偿
  - PARTIALLY_REACHABLE: 部分场景可达，存在条件限制
  - UNREACHABLE: 被前置 Filter 拦截或后置 Filter 补偿，实际不可触发

严重度调整规则：
  - REACHABLE: 保持原严重度
  - PARTIALLY_REACHABLE: 严重度降一级（如 HIGH→MEDIUM）
  - UNREACHABLE: 严重度降为 INFO（提示级别），仅作为代码质量提示
```

### Step 8: 熔断标记

若任一 Filter 的 P4/P5/P7 为 FAIL **且可达性为 REACHABLE 或 PARTIALLY_REACHABLE**，生成 `filter_bypassed` 熔断标记。

## 强制输出模板

> 详细输出模板见 [`references/phase2-filter-output.md`](references/phase2-filter-output.md)
> 配置深度审计清单见 [`references/filter-config-deep.md`](references/filter-config-deep.md)

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
