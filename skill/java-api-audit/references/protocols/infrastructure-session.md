# 会话管理安全审计清单

## SESSION-MGMT: 会话管理

**识别特征:** `HttpSession`, `SessionRegistry`, `SessionInformation`, `server.servlet.session.*`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CSM-01 | Session ID 生成 | Session ID 必须使用密码学安全随机数，长度 ≥ 128 bit | 检查 Tomcat Session ID 生成器配置 | HIGH |
| CSM-02 | Session Fixation | 认证成功后必须更换 Session ID | 检查 `SessionFixationProtection` 配置 | CRITICAL |
| CSM-03 | Session 超时 | 必须配置合理的超时时间（通常 30 分钟） | 检查 `server.servlet.session.timeout` | MEDIUM |
| CSM-04 | 并发会话控制 | 应限制同一用户的并发会话数 | 检查 `SessionRegistry` + `maximumSessions` | MEDIUM |
| CSM-05 | Session 数据泄露 | Session 中不得存储敏感数据 | 检查 `setAttribute` 存储的数据类型 | HIGH |
| CSM-06 | 登出清理 | 登出时必须使 Session 失效 + 清除 Cookie | 检查 logout 配置 | HIGH |
| CSM-07 | Session 劫持防护 | 敏感操作应重新验证身份 | 检查敏感操作是否要求重新认证 | HIGH |
| CSM-08 | Session 持久化 | 如使用分布式 Session（Redis），连接必须加密认证 | 检查 `spring.session.store-type` + Redis 配置 | HIGH |
| CSM-09 | Session Cookie 安全 | JSESSIONID 必须 HttpOnly + Secure + SameSite | 检查 Cookie 配置 | HIGH |
| CSM-10 | URL 重写 | 禁止在 URL 中传递 Session ID（jsessionid） | 检查是否禁用了 URL 重写 | HIGH |

---

## COOKIE-SEC: Cookie 安全

**识别特征:** `Cookie`, `ResponseCookie`, `Set-Cookie`, `@CookieValue`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CCOOK-01 | HttpOnly 标志 | 所有安全 Cookie 必须设置 HttpOnly | 搜索 Cookie 创建代码，检查 `setHttpOnly(true)` | HIGH |
| CCOOK-02 | Secure 标志 | HTTPS 环境下所有 Cookie 必须设置 Secure | 搜索 Cookie 创建代码，检查 `setSecure(true)` | HIGH |
| CCOOK-03 | SameSite 属性 | 应设置 SameSite=Lax 或 Strict | 搜索 SameSite 配置 | HIGH |
| CCOOK-04 | Cookie 路径 | Cookie 应设置正确的 Path，限制作用范围 | 检查 `setPath()` 配置 | MEDIUM |
| CCOOK-05 | Cookie 域名 | Cookie 域名不得过于宽泛（如 `.example.com`） | 检查 `setDomain()` 配置 | MEDIUM |
| CCOOK-06 | Cookie 大小 | Cookie 值不得包含大量数据（≤ 4KB） | 检查 Cookie 值大小 | LOW |
| CCOOK-07 | Cookie 注入 | Cookie 值不得直接拼接到响应头中 | 搜索 `addHeader("Set-Cookie", ...)` | HIGH |
| CCOOK-08 | Cookie 过期 | 安全 Cookie 应设置合理的 Max-Age/Expires | 检查 `setMaxAge()` 配置 | MEDIUM |

---

## SESSION-STORE: 分布式 Session 存储

**识别特征:** `spring.session.store-type`, `RedisHttpSession`, `SpringSessionBackedSessionRegistry`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CSS-01 | Redis 认证 | Redis 连接必须配置认证（密码） | 检查 `spring.redis.password` 配置 | HIGH |
| CSS-02 | Redis 加密 | Redis 连接应使用 TLS 加密 | 检查 `spring.redis.ssl` 配置 | MEDIUM |
| CSS-03 | Session 序列化 | Session 序列化应使用安全的方式（禁止 Java 原生序列化） | 检查序列化配置 | HIGH |
| CSS-04 | Session 隔离 | 不同应用的 Session 应有命名空间隔离 | 检查 `spring.session.redis.namespace` | MEDIUM |
| CSS-05 | Session 清理 | 过期 Session 应有自动清理机制 | 检查 Redis TTL 或定时清理任务 | LOW |
