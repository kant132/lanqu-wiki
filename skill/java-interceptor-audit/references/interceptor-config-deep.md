# Interceptor 配置安全语义深度审计

> **目标**: 当前 Interceptor 审计仅做模式匹配，但不理解每项配置的**安全语义**。
> 例如：检查"preHandle 是否返回 true？"但不检查"preHandle 中的鉴权逻辑是否可被绕过？"
>
> 本检查表要求：将每项 Interceptor 配置追溯到其对**具体端点**的实际安全影响，
> 并分析 Interceptor 与 Filter / SecurityFilterChain 的协作关系。

---

## IC-DEEP-01: preHandle 鉴权逻辑深度分析

不仅检查 `preHandle` 是否返回 `true`，还要深入分析鉴权逻辑的完整性：

1. **preHandle 中是否有认证/授权检查？**
   - 是否检查 `Authorization` header？
   - 是否检查 Session / Cookie？
   - 是否检查自定义 Token？
2. **认证检查是否可被绕过？**
   - 特定 Header 存在时跳过检查？（如 `X-Internal-Request: true`）
   - 特定 IP 地址跳过检查？（如 `127.0.0.1` 或内网 IP）
   - 特定 `User-Agent` 跳过检查？（如 `HealthCheck`）
   - 特定请求参数跳过检查？（如 `?debug=true`）
   - 特定 HTTP 方法跳过检查？（如 OPTIONS 请求）
3. **认证失败时的行为**：
   - 返回 `false`（正确）还是抛异常？
   - 是否设置了正确的响应码（401 未认证 / 403 未授权）？
   - 是否清除了已设置的响应内容？
   - 是否记录了认证失败日志（含失败原因、来源 IP）？

| Interceptor | preHandle行为 | 绕过条件 | 失败行为 | 风险 |
|------------|-------------|----------|----------|------|
| AuthInterceptor | 检查 Bearer token | 无 | 返回 false + 401 | PASS |
| UserInterceptor | 直接返回 true | N/A | N/A | FAIL(无鉴权) |
| InternalInterceptor | 检查 X-Internal header | header=secret123 | 返回 false + 403 | HIGH(header可伪造) |
| IpWhitelistInterceptor | 检查 IP 白名单 | 127.0.0.1 | 返回 false + 403 | MEDIUM(可被代理绕过) |
| DebugInterceptor | 检查 debug 参数 | ?debug=true | 返回 false + 400 | CRITICAL(参数可控) |

**判定标准**：
- `preHandle` 直接返回 `true` 且无鉴权逻辑 → **FAIL**
- 鉴权逻辑存在可被外部控制的绕过条件 → **CRITICAL**
- 认证失败未设置正确响应码 → **MEDIUM**
- 鉴权逻辑完整且无可绕过条件 → **PASS**

---

## IC-DEEP-02: 路径匹配深度分析

不仅检查 `addPathPatterns` / `excludePathPatterns`，还要分析路径匹配的安全性：

1. **路径匹配方式**：
   - 使用 `AntPathMatcher`（默认，Spring Boot 2.x）还是 `PathPatternParser`（Spring Boot 3.x 默认）？
   - 两种匹配器对特殊字符的处理差异是否导致安全问题？
2. **路径匹配与实际 Controller 路由的一致性**：
   - Interceptor 拦截 `/api/**` 但 Controller 路由是 `/api/v1/users`，是否完全覆盖？
   - 是否存在路径解析差异（如编码字符 `%2F`、矩阵参数 `;jsessionid=xxx`）？
   - Spring Boot 的尾部斜杠处理（`/api/users` vs `/api/users/`）是否影响拦截？
3. **排除路径的安全影响**：
   - 排除的路径是否包含状态变更操作（POST/PUT/DELETE）？
   - 排除的路径是否可通过路径变体访问受保护资源？
   - 排除路径是否过于宽泛（如 `/**`）？

| Interceptor | 包含路径 | 排除路径 | 排除路径中的端点 | 端点功能 | 风险 |
|------------|----------|----------|----------------|----------|------|
| AuthInterceptor | /api/** | /api/public/** | POST /api/public/webhook | 接收第三方回调 | MEDIUM |
| AuthInterceptor | /api/** | /api/health | GET /api/health | 健康检查 | PASS |
| AuthInterceptor | /admin/** | /admin/login | POST /admin/login | 管理员登录 | PASS |
| RateLimitInterceptor | /** | /static/** | GET /static/../api/users | 路径遍历风险 | HIGH |
| AuthInterceptor | /api/** | /api/v1/debug/** | GET /api/v1/debug/vars | 调试信息 | CRITICAL |

**判定标准**：
- 排除路径包含敏感状态变更端点 → **HIGH**
- 排除路径可通过路径变体绕过 → **CRITICAL**
- 排除路径过于宽泛（`/**`）→ **CRITICAL**
- 排除路径仅为公开只读端点 → **PASS**

---

## IC-DEEP-03: 拦截器链执行顺序分析

分析多个 Interceptor 的执行顺序及其安全影响：

1. **执行顺序**：`registry.addInterceptor()` 的调用顺序决定执行顺序
2. **安全检查的顺序是否正确**：
   - 认证 Interceptor 应在授权 Interceptor **之前**
   - 日志/审计 Interceptor 应在认证 **之后**（才能记录用户名）
   - 限流 Interceptor 应在认证 **之前**（防止暴力破解）
   - 请求验证 Interceptor 应在业务 Interceptor **之前**
3. **短路行为**：前一个 Interceptor 返回 `false` 时：
   - 后续 Interceptor 的 `preHandle` 是否被跳过？（是，这是正确行为）
   - 已执行的 Interceptor 的 `afterCompletion` 是否仍被调用？（是）
   - 短路时响应是否已正确设置？
4. **异常传播**：某个 Interceptor 抛出异常时：
   - 后续 Interceptor 是否被跳过？
   - 已执行的 Interceptor 的 `afterCompletion` 是否仍被调用？

| 执行顺序 | Interceptor | 功能 | 短路行为 | 顺序是否合理 |
|----------|------------|------|----------|-------------|
| 1 | RateLimitInterceptor | 限流 | 超限返回 429 | 合理(在认证前，防暴力破解) |
| 2 | AuthInterceptor | 认证 | 未认证返回 401 | 合理(在授权前) |
| 3 | RoleInterceptor | 角色授权 | 无权限返回 403 | 合理(在认证后) |
| 4 | AuditInterceptor | 审计日志 | 不短路 | 合理(在认证后，可记录用户) |
| 5 | ResponseInterceptor | 响应处理 | 不短路 | 合理(在最后) |

**判定标准**：
- 授权在认证之前 → **CRITICAL**
- 限流在认证之后（无法防暴力破解）→ **HIGH**
- 审计日志在认证之前（无法记录用户）→ **MEDIUM**
- 顺序合理且短路行为正确 → **PASS**

---

## IC-DEEP-04: afterCompletion 信息泄露分析

检查 `afterCompletion` / `postHandle` 是否泄露敏感信息：

1. **是否将敏感数据写入响应头？**
   - 自定义 header 中是否包含用户信息、内部 ID、调试信息？
   - `X-Request-Id` 是否泄露内部系统信息？
2. **是否在日志中记录敏感参数？**
   - 请求参数中是否包含密码、Token、密钥？
   - 请求体是否被完整记录（含敏感字段）？
   - 响应体是否被完整记录（含敏感数据）？
3. **是否修改响应体导致信息泄露？**
   - 是否在响应中添加了调试信息？
   - 是否在响应中暴露了内部处理时间、数据库查询信息？
4. **异常处理中的信息泄露**：
   - `afterCompletion` 中的 `Exception ex` 参数是否被记录到日志？
   - 异常堆栈是否被写入响应？

| Interceptor | 方法 | 操作 | 泄露内容 | 风险 |
|------------|------|------|----------|------|
| UserInterceptor | postHandle | 写入 model | username | LOW |
| AuditInterceptor | afterCompletion | 写入日志 | 请求参数(含密码) | HIGH |
| DebugInterceptor | postHandle | 添加响应头 | X-Debug-Info: SQL查询耗时 | MEDIUM |
| PerfInterceptor | afterCompletion | 写入日志 | 完整请求URL(含token参数) | HIGH |
| TraceInterceptor | afterCompletion | 写入响应头 | X-Trace-Id(含内部IP) | MEDIUM |
| LogInterceptor | afterCompletion | 写入日志 | 异常堆栈(含数据库信息) | HIGH |

**判定标准**：
- 日志中记录密码、Token、密钥 → **HIGH**
- 响应头中暴露内部系统信息 → **MEDIUM**
- 日志中记录完整异常堆栈（含敏感信息）→ **HIGH**
- 仅记录非敏感的操作日志 → **PASS**

---

## IC-DEEP-05: 与 Filter/SecurityFilterChain 的交互分析

分析 Interceptor 与 Filter 层的协作关系，确保安全控制无遗漏无冲突：

1. **Filter 层已做的安全检查，Interceptor 是否重复或遗漏？**
   - Spring Security 已做的认证，Interceptor 是否重复检查（性能浪费）？
   - Spring Security 未做的检查，Interceptor 是否补充？
2. **Filter 层的认证结果是否传递到 Interceptor？**
   - `SecurityContext` 是否在 Interceptor 中可用？
   - `request.getUserPrincipal()` 是否在 Interceptor 中可用？
   - Interceptor 是否依赖 Filter 设置的 `request attribute`？
3. **Interceptor 是否依赖 Filter 层设置的属性？**
   - 如果 Filter 未执行（如 `excludePathPatterns`），Interceptor 是否会因缺少属性而异常？
   - Interceptor 是否对缺失属性做了防御性检查？
4. **执行顺序**：
   - Filter 在 Interceptor **之前**执行（Servlet 容器层面）
   - Interceptor 在 Controller **之前**执行（Spring MVC 层面）
   - 确认安全检查的执行顺序是否符合预期

| 安全检查 | Filter层 | Interceptor层 | 协作方式 | 风险 |
|----------|---------|--------------|----------|------|
| 认证 | Spring Security (SecurityContext) | UserInterceptor (读取 SecurityContext) | 正确传递 | PASS |
| CSRF | 已禁用 | 无检查 | 无防护 | CRITICAL |
| 角色授权 | 无 | 无 | 无防护 | HIGH |
| 请求频率限制 | 无 | RateLimitInterceptor | 仅Interceptor层 | MEDIUM(单点防护) |
| 输入验证 | 无 | ValidationInterceptor | 仅Interceptor层 | MEDIUM(应提前到Filter) |
| CORS | CorsFilter | 无 | Filter层处理 | PASS |
| 请求日志 | RequestLoggingFilter | AuditInterceptor | 重复记录 | LOW(性能浪费) |

**判定标准**：
- Filter 和 Interceptor 均未做某项安全检查 → **CRITICAL**
- Interceptor 依赖 Filter 属性但未做防御性检查 → **HIGH**
- 安全检查仅在 Interceptor 层（可被绕过）→ **MEDIUM**
- Filter 和 Interceptor 协作良好，安全控制完整 → **PASS**

---

## 输出格式

审计完成后，按以下格式输出汇总结果：

```markdown
## Interceptor 配置深度审计结果

### IC-DEEP-01: preHandle 鉴权逻辑深度分析
- 状态: FAIL / PASS
- 发现: {N} 个 Interceptor 鉴权逻辑可被绕过 / 缺失
- Interceptor清单: (表格)

### IC-DEEP-02: 路径匹配深度分析
- 状态: FAIL / PASS
- 发现: {N} 个排除路径存在安全风险
- 路径清单: (表格)

### IC-DEEP-03: 拦截器链执行顺序分析
- 状态: FAIL / PASS
- 发现: 执行顺序问题
- 顺序清单: (表格)

### IC-DEEP-04: afterCompletion 信息泄露分析
- 状态: FAIL / PASS
- 发现: {N} 个 Interceptor 存在信息泄露
- 泄露清单: (表格)

### IC-DEEP-05: 与 Filter/SecurityFilterChain 的交互分析
- 状态: FAIL / PASS
- 发现: 协作问题 / 安全控制遗漏
- 协作清单: (表格)
```
