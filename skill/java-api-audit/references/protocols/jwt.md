# JWT 令牌生命周期安全审计清单

## JWT-LIFECYCLE: JWT 令牌生命周期

### 识别特征

```
库: jjwt, java-jwt, jose4j, nimbus-jose-jwt, spring-security-oauth2-jose
类: Jwt, JwtDecoder, JwtEncoder, JwtAuthenticationProvider
配置: jwt.secret, jwt.expiration, jwt.issuer
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| JWT-01 | 签名算法固定 | 必须固定使用强算法（RS256/ES256），禁止接受 token 中声明的 alg | 检查 JwtDecoder 是否固定算法；检查是否验证 alg header；是否允许 alg=none | CRITICAL |
| JWT-02 | 密钥强度 | HMAC 密钥 ≥ 256 bit；RSA 密钥 ≥ 2048 bit；禁止硬编码弱密钥 | 检查密钥来源和长度；搜索硬编码密钥（如 "secret", "victory"） | CRITICAL |
| JWT-03 | 密钥管理 | 密钥应通过安全渠道注入（环境变量/KMS），不得硬编码在代码中 | 搜索密钥定义代码；检查是否使用 @Value 从环境变量读取 | CRITICAL |
| JWT-04 | 过期时间(exp) | access_token 应有短过期时间（15-60 分钟）；必须验证 exp | 检查 exp 设置值；检查验证时是否校验 exp | HIGH |
| JWT-05 | 发行者(iss)验证 | 必须验证 token 的 iss 声明匹配预期 | 检查 JwtDecoder 的 issuer 配置 | HIGH |
| JWT-06 | 受众(aud)验证 | 必须验证 token 的 aud 声明包含本服务 | 检查是否有 AudienceValidator | HIGH |
| JWT-07 | Claims 注入 | 写入 JWT 的用户输入必须经过校验，防止 claims 注入 | 检查 JWT 构建时是否直接使用未校验的用户输入 | MEDIUM |
| JWT-08 | kid 头安全 | 如果 JWT 使用 kid 头指定密钥，kid 值不得直接拼接到 SQL/LDAP 查询中 | 检查 kid 的使用方式；是否拼接到查询语句 | CRITICAL |
| JWT-09 | jku/jwk 头安全 | 如果 JWT 使用 jku/jwk 头，URL 必须来自白名单，防止 SSRF | 检查 jku URL 是否白名单校验；是否从任意 URL 获取公钥 | CRITICAL |
| JWT-10 | Token 撤销 | 应支持主动撤销 JWT（黑名单或短过期+刷新令牌） | 检查是否有 token 黑名单机制；登出时是否处理 token | MEDIUM |
