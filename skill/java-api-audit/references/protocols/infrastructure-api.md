# API 基础设施安全审计清单

## API-GATEWAY: API 网关/限流

**识别特征:** `RateLimiter`, `Throttle`, `Gateway`, `Zuul`, Spring Cloud Gateway, `Bucket4j`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CAPI-01 | 速率限制 | 所有公开 API 应有速率限制 | 检查是否有 `RateLimiter`/`Throttle` 配置 | HIGH |
| CAPI-02 | 限流粒度 | 限流应按用户/IP/API Key 粒度 | 检查限流配置的 key 策略 | MEDIUM |
| CAPI-03 | 请求大小限制 | 应限制请求体/URL 长度 | 检查 `max-request-size` 配置 | MEDIUM |
| CAPI-04 | 超时配置 | 网关应配置请求/响应超时 | 检查 timeout 配置 | MEDIUM |
| CAPI-05 | 路由安全 | 网关路由规则不得暴露内部服务地址 | 检查路由配置 | HIGH |
| CAPI-06 | 请求日志 | 网关应记录所有请求（含来源 IP、路径、响应码） | 检查日志配置 | MEDIUM |
| CAPI-07 | WAF 集成 | 生产环境应集成 WAF（Web Application Firewall） | 检查是否有 WAF 配置 | LOW |

---

## CORS-CONFIG: CORS 跨域配置

**识别特征:** `CorsConfiguration`, `@CrossOrigin`, `CorsFilter`, `CorsConfigurationSource`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CCORS-01 | Origin 白名单 | `allowedOrigins` 不得为 `*`（生产环境） | 检查 `CorsConfiguration.setAllowedOrigins` | HIGH |
| CCORS-02 | Credentials + 通配符 | `allowCredentials=true` 时 `allowedOrigins` 不得为 `*` | 检查两者组合 | CRITICAL |
| CCORS-03 | 方法限制 | `allowedMethods` 应仅包含必要方法 | 检查 `setAllowedMethods` | MEDIUM |
| CCORS-04 | 头部限制 | `allowedHeaders` 应仅包含必要头部 | 检查 `setAllowedHeaders` | LOW |
| CCORS-05 | 预检缓存 | `maxAge` 应设置合理值 | 检查 `setMaxAge` | LOW |
| CCORS-06 | 暴露头部 | `exposedHeaders` 不得暴露敏感头部 | 检查 `setExposedHeaders` | MEDIUM |
