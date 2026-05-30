# Filter 配置安全语义深度审计

> **目标**: 当前 Filter 审计（P1-P7）仅对代码做模式匹配，但不理解每项配置的**安全语义**。
> 例如：检查"CSRF 是否禁用？"但不检查"CSRF 禁用后，每个状态变更端点有哪些补偿控制措施？"
>
> 本检查表要求：将每项配置追溯到其对**具体端点**的实际安全影响。

---

## SC-DEEP-01: CSRF 禁用影响分析

当检测到 `csrf.disable()` 或 `CsrfConfigurer.disable()` 时，必须执行以下分析：

1. **枚举所有状态变更端点**（POST / PUT / DELETE / PATCH）
2. **对每个端点检查是否存在替代 CSRF 防护**：
   - 自定义 Token 校验（如 `X-XSRF-TOKEN` header）
   - `SameSite` Cookie 属性（`Strict` 或 `Lax`）
   - `Origin` / `Referer` header 校验
   - Double Submit Cookie 模式
3. **输出**：无 CSRF 防护的状态变更端点清单

| 端点 | HTTP方法 | 业务操作 | 替代CSRF防护 | 风险 |
|------|----------|----------|-------------|------|
| POST /api/transfer | POST | 资金转账 | 无 | CRITICAL |
| POST /api/profile | POST | 修改个人资料 | SameSite=Lax | LOW |
| DELETE /api/account | DELETE | 注销账户 | 无 | CRITICAL |
| PUT /api/settings | PUT | 修改系统配置 | X-XSRF-TOKEN | PASS |

**判定标准**：
- 任何涉及资金、权限、敏感数据修改的端点无替代防护 → **CRITICAL**
- 普通数据修改端点无替代防护 → **HIGH**
- 所有状态变更端点均有替代防护 → **PASS**

---

## SC-DEEP-02: permitAll 路径深度分析

不仅列出 `permitAll()` 路径，还要执行以下分析：

1. **将每个 `permitAll` 路径与实际 API 端点交叉匹配**
2. **对匹配的每个端点评估**：
   - 该端点是否执行状态变更操作？
   - 该端点是否返回敏感数据？
   - 该端点是否有应用层认证检查（如手动检查 `SecurityContext`）？
3. **检查 `permitAll` 路径是否存在路径绕过风险**：
   - 路径遍历：`/api/public/**` 是否可通过 `/api/public/../admin/secret` 访问受保护路径？
   - 尾部斜杠差异：`/api/public` vs `/api/public/`
   - 大小写差异：`/Api/Public` vs `/api/public`
   - 编码字符：`/api/%70ublic` vs `/api/public`
   - 矩阵参数：`/api/public;param=value` 是否绕过路径匹配？

| permitAll路径 | 匹配的端点 | 端点功能 | 状态变更? | 敏感数据? | 应用层认证? | 风险 |
|--------------|-----------|----------|----------|----------|-----------|------|
| /actuator/** | /actuator/env | 环境变量 | 否 | 是(数据库密码) | 无 | CRITICAL |
| /actuator/** | /actuator/heapdump | 堆转储 | 否 | 是(内存数据) | 无 | CRITICAL |
| /register.mvc | POST /register.mvc | 用户注册 | 是 | 否 | 无 | MEDIUM |
| /api/public/** | GET /api/public/status | 系统状态 | 否 | 否 | 无 | PASS |
| /login | POST /login | 登录认证 | 是 | 否 | 无 | PASS |

**判定标准**：
- `permitAll` 端点返回敏感数据且无应用层认证 → **CRITICAL**
- `permitAll` 端点执行状态变更（非登录/注册）且无应用层认证 → **HIGH**
- 存在路径绕过风险 → **HIGH**
- 仅公开数据端点为 `permitAll` → **PASS**

---

## SC-DEEP-03: 密码编码器链路分析

不仅检查 `PasswordEncoder` 类型，还要追踪密码从输入到存储的完整链路：

1. **追踪密码在系统中的完整生命周期**：
   - 注册链路：`@RequestParam password` → `encode()` → 数据库
   - 登录链路：`@RequestParam password` → `matches()` → 比对
   - 修改密码链路：旧密码验证 → 新密码 `encode()` → 数据库
   - 重置密码链路：新密码生成/输入 → `encode()` → 数据库
2. **检查密码是否在链路中被日志记录**：
   - `log.info/debug/error` 中是否包含密码参数
   - AOP 日志切面是否记录方法参数（含密码）
3. **检查密码是否在异常消息中泄露**：
   - 认证失败消息是否包含密码
   - 验证失败消息是否包含密码
4. **检查所有密码操作是否使用相同的编码器**：
   - 注册和登录是否使用同一个 `PasswordEncoder` 实例
   - 密码修改/重置是否使用相同编码器

| 链路 | 编码器 | 位置 | 日志泄露? | 异常泄露? | 风险 |
|------|--------|------|----------|----------|------|
| 注册 | NoOpPasswordEncoder | UserService.java:45 | 否 | 否 | CRITICAL(明文存储) |
| 登录 | NoOpPasswordEncoder | UserService.java:67 | 否 | 是(失败消息含密码) | CRITICAL |
| 修改密码 | BCryptPasswordEncoder | UserService.java:89 | 否 | 否 | PASS |
| 重置密码 | BCryptPasswordEncoder | UserService.java:112 | 是(log.info记录参数) | 否 | HIGH |

**判定标准**：
- 使用 `NoOpPasswordEncoder` → **CRITICAL**
- 使用 `MD5` 无盐编码 → **HIGH**
- 密码在日志中泄露 → **HIGH**
- 密码在异常消息中泄露 → **MEDIUM**
- 注册/登录使用不同编码器 → **HIGH**
- 使用 `BCrypt`/`Argon2`/`SCrypt` 且无泄露 → **PASS**

---

## SC-DEEP-04: CORS 配置实际影响分析

不仅检查 CORS 配置值，还要分析其对具体端点的实际安全影响：

1. **识别哪些端点实际受到 CORS 配置影响**
2. **评估跨域请求的实际风险**：
   - 该端点是否携带认证信息（Cookie / Authorization header）？
   - 跨域请求能否执行状态变更操作？
   - `allowCredentials` 是否与 `allowedOrigins=*` 同时存在？
3. **检查 `@CrossOrigin` 注解是否覆盖了全局配置**：
   - 注解中的 `origins` 是否比全局配置更宽松？
   - 注解中的 `methods` 是否允许了不必要的方法？
4. **检查 `allowedOrigins` 中的具体域名**：
   - 是否包含不受信任的域名？
   - 是否使用通配符子域名（`*.example.com`）且子域名可被攻击者控制？

| 端点 | 全局CORS | 注解CORS | 携带认证? | 状态变更? | 实际风险 |
|------|----------|---------|----------|----------|----------|
| POST /api/transfer | Origin=* | 无 | 是(Cookie) | 是 | CRITICAL |
| GET /api/health | Origin=* | 无 | 否 | 否 | LOW |
| POST /api/admin/users | Origin=trusted.com | @CrossOrigin(origins="*") | 是(JWT) | 是 | CRITICAL(注解覆盖) |
| GET /api/public/docs | Origin=* | 无 | 否 | 否 | PASS |

**判定标准**：
- `allowedOrigins=*` + `allowCredentials=true` → **CRITICAL**（浏览器会阻止，但配置意图错误）
- 状态变更端点 + `Origin=*` + 携带认证 → **CRITICAL**
- `@CrossOrigin` 注解覆盖全局配置使安全降级 → **HIGH**
- 仅公开只读端点允许跨域 → **PASS**

---

## SC-DEEP-05: 会话管理配置完整性分析

不仅检查单个配置项，还要评估会话管理全生命周期的完整性：

1. **会话生命周期各阶段**：创建 → 使用 → 续期 → 过期 → 销毁
2. **每个阶段的安全检查**：
   - **创建**：Session ID 强度、Session Fixation 防护
   - **使用**：Cookie 属性（HttpOnly / Secure / SameSite）、并发控制
   - **续期**：滑动过期 vs 固定过期、最大会话时长
   - **过期**：超时配置、空闲超时、绝对超时
   - **销毁**：登出清理、Session 失效、Cookie 清除
3. **并发会话控制**：
   - 是否限制同一用户的并发会话数？
   - 超出限制时的策略（踢掉旧会话 vs 拒绝新登录）

| 阶段 | 配置项 | 当前值 | 安全要求 | 差距 | 风险 |
|------|--------|--------|----------|------|------|
| 创建 | SessionFixationProtection | migrateSession | changeSessionId | 可接受 | LOW |
| 创建 | Session ID 来源 | SecureRandom | SecureRandom | 无 | PASS |
| 使用 | Cookie.HttpOnly | true | true | 无 | PASS |
| 使用 | Cookie.Secure | false | true | 缺失 | HIGH |
| 使用 | Cookie.SameSite | 未设置 | Lax/Strict | 缺失 | MEDIUM |
| 使用 | 最大并发会话 | 无限制 | 限制(如3) | 缺失 | MEDIUM |
| 续期 | 过期策略 | 滑动过期 | 滑动+绝对上限 | 缺绝对上限 | MEDIUM |
| 过期 | session.timeout | 未配置 | 30分钟 | 缺失 | HIGH |
| 过期 | maxInactiveInterval | 未配置 | 30分钟 | 缺失 | HIGH |
| 销毁 | logout.invalidateHttpSession | true | true | 无 | PASS |
| 销毁 | logout.deleteCookies | 未配置 | 清除JSESSIONID | 缺失 | MEDIUM |

**判定标准**：
- 无会话超时配置 → **HIGH**
- Cookie 缺少 `Secure` 标志（HTTPS 环境）→ **HIGH**
- 无 Session Fixation 防护 → **HIGH**
- Cookie 缺少 `HttpOnly` → **CRITICAL**
- 所有阶段均有合理配置 → **PASS**

---

## SC-DEEP-06: 多 SecurityFilterChain 交互分析

当存在多个 `SecurityFilterChain` Bean 时，必须分析其交互关系：

1. **分析 `@Order` 值**决定哪个 Chain 优先匹配
2. **分析 `securityMatcher` 的路径覆盖关系**：
   - 哪些路径被哪个 Chain 覆盖？
   - 是否存在路径重叠（同一请求匹配多个 Chain）？
   - 是否存在路径遗漏（某些请求不匹配任何 Chain）？
3. **检查每个 Chain 的安全配置是否一致**：
   - 高安全级别的 Chain 是否被低安全级别的 Chain 绕过？
   - 默认 Chain（`anyRequest`）的安全配置是否足够？
4. **检查 Chain 之间的 Filter 共享**：
   - 共享的 Filter 是否在不同 Chain 中有不同行为？

| Chain | Order | securityMatcher | 覆盖路径 | 与其他Chain重叠? | 遗漏路径? |
|-------|-------|----------------|----------|----------------|----------|
| WebGoat | 1 | /WebGoat/** | /WebGoat/* | 无 | 无 |
| WebWolf | 2 | /WebWolf/** | /WebWolf/* | 无 | 无 |
| API | 3 | /api/** | /api/* | 无 | 无 |
| Default | @Order(MAX) | anyRequest | /** | 覆盖所有剩余 | 无 |

**判定标准**：
- 存在路径遗漏（请求不匹配任何 Chain）→ **CRITICAL**
- 高安全路径被低安全 Chain 匹配 → **CRITICAL**
- 路径重叠导致安全配置不确定 → **HIGH**
- 所有路径明确覆盖且安全配置合理 → **PASS**

---

## SC-DEEP-07: OAuth2 配置安全语义分析

不仅检查 `spring.security.oauth2.*` 配置值，还要理解 OAuth2 流程中每一步的安全含义：

1. **授权请求阶段**：
   - `redirect_uri` 是否严格匹配（不使用通配符）？
   - `state` 参数是否生成并绑定到用户会话？
   - `scope` 是否遵循最小权限原则？
2. **回调处理阶段**：
   - 是否验证 `state` 参数防止 CSRF？
   - 是否验证 `authorization code` 的一次性使用？
   - 错误回调是否泄露敏感信息？
3. **Token 获取阶段**：
   - `client_secret` 如何传递（POST body vs Basic Auth）？
   - 是否使用 PKCE（Public Client 必须使用）？
   - Token 端点是否使用 HTTPS？
4. **Token 使用阶段**：
   - Access Token 如何存储（内存 vs Cookie vs LocalStorage）？
   - Access Token 如何传递（Authorization header vs query param）？
   - Refresh Token 的轮换策略？
5. **Token 验证阶段**：
   - 是否验证签名（JWS）？
   - 是否验证过期时间（`exp` claim）？
   - 是否验证 `audience`（`aud` claim）？
   - 是否验证 `issuer`（`iss` claim）？

详细检查项见 `protocols/oauth2.md`

**判定标准**：
- Public Client 未使用 PKCE → **CRITICAL**
- 未验证 `state` 参数 → **CRITICAL**
- Token 通过 URL query param 传递 → **HIGH**
- 未验证 `audience` / `issuer` → **HIGH**
- 所有步骤均有正确安全配置 → **PASS**

---

## SC-DEEP-08: 错误处理信息泄露分析

检查 `AuthenticationEntryPoint` 和 `AccessDeniedHandler` 的信息泄露风险：

1. **认证失败时返回什么信息？**
   - 是否泄露用户名是否存在（如"用户名不存在"vs"密码错误"）？
   - 是否泄露内部实现（如"JWT token expired"vs"认证失败"）？
   - 是否泄露认证方式（如"LDAP 连接失败"）？
2. **授权失败时返回什么信息？**
   - 是否泄露所需角色（如"需要 ADMIN 角色"）？
   - 是否泄露资源权限配置？
3. **异常处理**：
   - 全局异常处理器（`@ControllerAdvice`）是否返回堆栈跟踪？
   - 自定义错误页面是否泄露技术细节（框架版本、数据库类型）？
   - Spring Boot 默认错误页面（Whitelabel）是否暴露？

| 场景 | 处理器 | 返回内容 | 泄露信息 | 风险 |
|------|--------|----------|----------|------|
| 认证失败 | AjaxAuthenticationEntryPoint | 401 + exception message | 异常类型 | MEDIUM |
| 认证失败 | LoginFailureHandler | "用户名不存在" | 用户名枚举 | HIGH |
| 授权失败 | 默认 | 403 Forbidden | 无 | PASS |
| 授权失败 | CustomAccessDeniedHandler | "需要 ROLE_ADMIN" | 所需角色 | HIGH |
| 服务器错误 | BasicErrorController | 堆栈跟踪 | 完整调用链 | HIGH |
| Token过期 | JwtAuthenticationEntryPoint | "JWT expired at 2024-01-01" | Token实现细节 | MEDIUM |

**判定标准**：
- 返回堆栈跟踪 → **HIGH**
- 泄露用户名是否存在 → **HIGH**
- 泄露所需角色/权限 → **HIGH**
- 泄露内部实现细节（JWT/LDAP/数据库）→ **MEDIUM**
- 统一返回通用错误消息 → **PASS**

---

## 输出格式

审计完成后，按以下格式输出汇总结果：

```markdown
## Filter 配置深度审计结果

### SC-DEEP-01: CSRF 禁用影响分析
- 状态: FAIL / PASS
- 影响: {N} 个状态变更端点无 CSRF 防护
- 端点清单: (表格)

### SC-DEEP-02: permitAll 路径深度分析
- 状态: FAIL / PASS
- 发现: {N} 个 permitAll 端点返回敏感数据 / 执行状态变更
- 端点清单: (表格)

### SC-DEEP-03: 密码编码器链路分析
- 状态: FAIL / PASS
- 发现: 编码器类型 / 泄露情况
- 链路清单: (表格)

### SC-DEEP-04: CORS 配置实际影响分析
- 状态: FAIL / PASS
- 影响: {N} 个端点存在跨域安全风险
- 端点清单: (表格)

### SC-DEEP-05: 会话管理配置完整性分析
- 状态: FAIL / PASS
- 发现: {N} 个阶段存在配置缺失
- 配置清单: (表格)

### SC-DEEP-06: 多 SecurityFilterChain 交互分析
- 状态: FAIL / PASS / N/A（仅一个 Chain）
- 发现: 路径重叠/遗漏情况
- Chain清单: (表格)

### SC-DEEP-07: OAuth2 配置安全语义分析
- 状态: FAIL / PASS / N/A（未使用 OAuth2）
- 发现: 各阶段安全问题
- 详细结果: 见 protocols/oauth2.md 审计输出

### SC-DEEP-08: 错误处理信息泄露分析
- 状态: FAIL / PASS
- 发现: {N} 个场景存在信息泄露
- 场景清单: (表格)
```
