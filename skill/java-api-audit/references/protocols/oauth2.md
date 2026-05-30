# OAuth2 / OIDC 协议安全审计清单

## 协议索引

| 协议ID | 协议名称 | 识别特征 | 检查项数 |
|--------|----------|----------|----------|
| OAUTH2-AC | OAuth2 授权码流程 | @EnableOAuth2Client, OAuth2AuthorizedClient, authorization_code | 12 |
| OAUTH2-IM | OAuth2 隐式流程 | response_type=token, implicit | 8 |
| OAUTH2-PKCE | OAuth2 PKCE | code_challenge, code_verifier, S256 | 6 |
| OIDC | OpenID Connect | id_token, UserInfo, @RegisteredOAuth2AuthorizedClient | 8 |
| OAUTH2-RT | OAuth2 刷新令牌 | refresh_token, RefreshToken, OAuth2AuthorizedClient refresh | 7 |

---

## OAUTH2-AC: OAuth2 授权码流程

### 识别特征

```
注解/配置: @EnableOAuth2Client, @EnableOAuth2Sso, spring-boot-starter-oauth2-client
配置项: spring.security.oauth2.client.registration.*, spring.security.oauth2.client.provider.*
类: OAuth2AuthorizedClient, OAuth2AuthorizationRequest, OAuth2AuthorizationCodeGrantFilter
端点: /oauth2/authorization/*, /login/oauth2/code/*, /oauth/authorize, /oauth/token
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| OAC-01 | redirect_uri 校验 | redirect_uri 必须严格匹配预注册值，禁止开放重定向 | 检查 OAuth2AuthorizationRequest 的 redirectUri 是否使用精确匹配；检查是否有自定义 redirect_uri 参数接受用户输入 | CRITICAL |
| OAC-02 | state 参数防 CSRF | 授权请求必须包含不可预测的 state 参数，回调时验证 state 一致性 | 检查 AuthorizationRequestRepository 是否生成并存储 state；检查回调处理是否验证 state 匹配 | CRITICAL |
| OAC-03 | 授权码一次性使用 | 授权码(code)必须只能使用一次，使用后立即失效 | 检查 AuthorizationCodeTokenResponseClient 是否处理重复使用；检查是否有自定义缓存/存储授权码 | HIGH |
| OAC-04 | 授权码与 client_id 绑定 | 授权码必须与申请时的 client_id 绑定，防止授权码拦截攻击 | 检查 token 请求是否携带正确的 client_id；检查 Authorization Code 是否与 client 关联存储 | HIGH |
| OAC-05 | client_secret 保护 | client_secret 不得出现在前端代码、URL 参数、日志中 | 搜索 client_secret/clientSecret 在代码中的引用；检查是否硬编码；检查是否通过环境变量注入 | CRITICAL |
| OAC-06 | token 端点认证 | 向 token 端点发送请求时必须携带 client 认证（Basic Auth 或 POST body） | 检查 ClientAuthenticationMethod 配置；检查是否使用 client_secret_basic 或 client_secret_post | HIGH |
| OAC-07 | PKCE 支持 | 公开客户端（SPA/移动端）必须使用 PKCE，机密客户端建议使用 | 检查是否配置 code_challenge_method；检查 AuthorizationRequest 是否包含 code_challenge | HIGH |
| OAC-08 | scope 校验 | 请求的 scope 必须在授权服务器允许的范围内，防止 scope 提升 | 检查 OAuth2AuthorizationRequest 的 scope 是否硬编码或白名单校验；检查返回的 token scope 是否被验证 | MEDIUM |
| OAC-09 | token 存储安全 | access_token/refresh_token 不得存储在 localStorage（XSS 可窃取），应使用 HttpOnly Cookie 或内存 | 搜索 token 存储逻辑；检查是否写入 Cookie（HttpOnly/Secure/SameSite）；检查是否存入 localStorage/sessionStorage | HIGH |
| OAC-10 | token 传输安全 | token 仅通过 HTTPS 传输，不得在 URL 参数中传递 | 检查 token 是否通过 Authorization header 传递；检查是否有 URL 参数传递 token 的场景 | HIGH |
| OAC-11 | 错误信息泄露 | OAuth2 错误响应不得泄露内部实现细节（如 stack trace、内部 URL） | 检查 AuthenticationFailureHandler / OAuth2AuthorizationRequestResolver 的错误处理；检查是否返回详细错误消息 | MEDIUM |
| OAC-12 | 授权服务器元数据验证 | 应验证授权服务器的 issuer、jwks_uri 等元数据，防止钓鱼授权服务器 | 检查 provider 配置是否使用 issuer-uri 自动发现；检查是否手动配置了所有端点 URL | MEDIUM |

### 已知攻击向量

```
1. 授权码拦截攻击: 攻击者拦截授权码，在自己的 token 请求中使用
   前提: redirect_uri 校验不严 + 无 PKCE
   验证: 构造恶意 redirect_uri，观察是否被接受

2. CSRF 攻击: 攻击者将自己的授权码绑定到受害者的会话
   前提: 无 state 参数或 state 可预测
   验证: 检查 state 参数的生成和验证逻辑

3. 开放重定向: redirect_uri 参数可被操纵，导致用户被重定向到恶意网站
   验证: 修改 redirect_uri 为外部 URL，观察是否被接受

4. client_secret 泄露: 硬编码在代码中或通过不安全渠道传输
   验证: 搜索代码中的 client_secret 引用

5. Scope 提升: 请求超出授权的 scope
   验证: 修改 scope 参数，观察是否被拒绝
```

---

## OAUTH2-IM: OAuth2 隐式流程

### 识别特征

```
配置项: response_type=token, grant_type=implicit
端点: /oauth/authorize (response_type=token)
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| OIM-01 | 是否仍使用隐式流程 | OAuth 2.1 草案已弃用隐式流程，应迁移到授权码+PKCE | 检查是否存在 response_type=token 的配置 | HIGH |
| OIM-02 | token 在 URL fragment 中暴露 | access_token 出现在 URL fragment (#) 中，可被浏览器历史/Referer 泄露 | 检查 token 是否通过 fragment 传递；检查是否有 Referer 泄露防护 | HIGH |
| OIM-03 | redirect_uri 严格校验 | 隐式流程的 redirect_uri 必须精确匹配，因为 token 直接在重定向中返回 | 同 OAC-01 | CRITICAL |
| OIM-04 | 无刷新令牌 | 隐式流程不返回 refresh_token，token 过期后需要重新授权 | 检查是否有 refresh_token 相关逻辑 | LOW |
| OIM-05 | token 存储 | 前端如何存储从 fragment 获取的 token | 检查前端 JS 代码中的 token 存储方式 | HIGH |
| OIM-06 | state 参数 | 同 OAC-02 | 同 OAC-02 | CRITICAL |
| OIM-07 | token 泄露 via Referer | 页面中的外部链接/资源可能导致 token 通过 Referer header 泄露 | 检查是否配置 Referrer-Policy；检查页面是否包含外部资源 | HIGH |
| OIM-08 | 混合流程风险 | response_type=code+token 混合模式的风险 | 检查是否存在混合 response_type | MEDIUM |

---

## OAUTH2-PKCE: OAuth2 PKCE

### 识别特征

```
参数: code_challenge, code_challenge_method, code_verifier
类: PkceParameters, DefaultAuthorizationCodeTokenResponseClient (with PKCE)
配置: spring.security.oauth2.client.registration.*.client-authentication-method=none
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| OPKCE-01 | code_challenge_method 必须为 S256 | 禁止使用 plain 方法，必须使用 S256（SHA-256 哈希） | 检查 code_challenge_method 配置；搜索 "plain" 关键字 | CRITICAL |
| OPKCE-02 | code_verifier 熵值 | code_verifier 必须是高熵随机值（43-128 字符，[A-Z][a-z][0-9]-._~） | 检查 code_verifier 生成逻辑；是否使用 SecureRandom | HIGH |
| OPKCE-03 | code_verifier 与 code_challenge 绑定 | 同一授权请求的 code_verifier 和 code_challenge 必须对应 | 检查存储和检索逻辑 | HIGH |
| OPKCE-04 | code_verifier 一次性使用 | code_verifier 使用后必须销毁，不得重复使用 | 检查 token 交换后是否清除 code_verifier | MEDIUM |
| OPKCE-05 | 公开客户端强制 PKCE | 无 client_secret 的客户端（SPA/移动端）必须使用 PKCE | 检查 client-authentication-method=none 的客户端是否配置了 PKCE | CRITICAL |
| OPKCE-06 | 授权服务器 PKCE 支持 | 授权服务器必须验证 code_verifier，否则 PKCE 形同虚设 | 如果是自建授权服务器，检查 token 端点是否验证 code_verifier | HIGH |

---

## OIDC: OpenID Connect

### 识别特征

```
配置: spring.security.oauth2.client.registration.*.scope=openid
类: OidcUser, OidcIdTokenDecoderFactory, JwtDecoder
端点: /userinfo, /.well-known/openid-configuration
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| OIDC-01 | id_token 签名验证 | 必须验证 id_token 的签名（使用授权服务器的公钥/JWKS） | 检查 JwtDecoder 配置；检查是否使用 JWS 验证 | CRITICAL |
| OIDC-02 | id_token 受众(aud)验证 | id_token 的 aud 声明必须包含本应用的 client_id | 检查 OAuth2TokenValidator 是否包含 AudienceValidator | CRITICAL |
| OIDC-03 | id_token 发行者(iss)验证 | id_token 的 iss 声明必须匹配预期的授权服务器 | 检查 JwtDecoder 的 issuer-uri 配置 | CRITICAL |
| OIDC-04 | id_token 过期(exp)验证 | 必须验证 id_token 的 exp 声明，拒绝过期 token | 检查 ClockSkew 配置；检查是否有自定义过期逻辑 | HIGH |
| OIDC-05 | nonce 防重放 | 授权请求应包含 nonce，id_token 中的 nonce 必须匹配 | 检查 AuthorizationRequest 是否包含 nonce；检查 id_token 验证是否校验 nonce | HIGH |
| OIDC-06 | UserInfo 端点安全 | UserInfo 请求应使用 Bearer token，响应应验证 sub 与 id_token 一致 | 检查 UserInfo 请求方式；检查 sub 一致性验证 | MEDIUM |
| OIDC-07 | 算法混淆攻击 | 禁止接受 alg=none 的 id_token；禁止 RSA/HMAC 算法混淆 | 检查 JWSAlgorithm 配置；检查是否限制允许的算法 | CRITICAL |
| OIDC-08 | id_token 中的敏感信息 | id_token 可能包含敏感 claims（email、phone），需评估是否应加密 | 检查 id_token 中的 claims 列表；检查是否使用 JWE 加密 | MEDIUM |

---

## OAUTH2-RT: OAuth2 刷新令牌

### 识别特征

```
参数: refresh_token, grant_type=refresh_token
类: OAuth2RefreshToken, RefreshTokenOAuth2AuthorizedClientProvider
配置: spring.security.oauth2.client.registration.*.scope 包含 offline_access
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| ORT-01 | refresh_token 存储安全 | refresh_token 必须安全存储（服务端加密/HttpOnly Cookie），不得暴露给前端 | 搜索 refresh_token 存储逻辑；检查是否存入数据库（是否加密）；检查是否通过 Cookie 传递 | CRITICAL |
| ORT-02 | refresh_token 轮换 | 每次使用 refresh_token 获取新 access_token 时，应同时轮换 refresh_token | 检查 token 响应处理逻辑；检查旧 refresh_token 是否失效 | HIGH |
| ORT-03 | refresh_token 过期 | refresh_token 应有合理的过期时间，不得永不过期 | 检查 refresh_token 的 TTL 配置；检查是否有绝对过期时间 | HIGH |
| ORT-04 | refresh_token 撤销 | 应支持主动撤销 refresh_token（用户登出/密码修改时） | 检查是否有 revoke token 逻辑；检查登出时是否清除 refresh_token | HIGH |
| ORT-05 | refresh_token 与 client 绑定 | refresh_token 必须与申请时的 client_id 绑定 | 检查 token 刷新请求是否验证 client_id 一致性 | HIGH |
| ORT-06 | scope 收窄 | 刷新时请求的 scope 不得超过原始授权的 scope | 检查 refresh token 请求的 scope 参数验证 | MEDIUM |
| ORT-07 | 离线访问风险 | offline_access scope 意味着 refresh_token 长期有效，需额外保护 | 检查是否申请了 offline_access；检查对应的保护措施 | MEDIUM |
