# 认证协议审计分支

## 触发条件

- 标签: `OAUTH2`, `SAML`, `CAS_TICKET`, `SHIRO`, `SPRING_SECURITY`, `JWT_ADVANCED`, `OIDC`, `KERBEROS`
- 优先级: 1（高危）

## 审计检查点

### OAuth2 / OIDC

| 检查项 | 说明 |
|--------|------|
| OA1 | `redirect_uri` 是否严格校验（白名单 + 精确匹配）？ |
| OA2 | `state` 参数是否生成并校验（防CSRF）？ |
| OA3 | `code` 是否一次性使用且绑定 `redirect_uri`？ |
| OA4 | Access Token 是否校验签名、过期时间、issuer？ |
| OA5 | 是否存在 Authorization Code 拦截（Open Redirect 导致）？ |
| OA6 | PKCE 是否正确实现（S256 而非 plain）？ |
| OA7 | Refresh Token 是否支持撤销和轮换？ |
| OA8 | OIDC `nonce` 是否校验（防重放）？ |
| OA9 | 是否存在 `jwks_uri` 劫持风险？ |
| OA10 | Implicit Flow 是否被禁用（推荐 Authorization Code + PKCE）？ |

### SAML

| 检查项 | 说明 |
|--------|------|
| SA1 | SAML Response 签名是否校验？ |
| SA2 | 是否存在 XML Signature Wrapping 攻击风险？ |
| SA3 | `Audience` 限制是否校验？ |
| SA4 | `NotBefore` / `NotOnOrAfter` 时间条件是否校验？ |
| SA5 | `InResponseTo` 是否校验（防重放）？ |
| SA6 | 是否存在 XXE 注入（SAML 基于 XML）？ |
| SA7 | NameID 是否可信（是否可被伪造）？ |

### CAS

| 检查项 | 说明 |
|--------|------|
| CA1 | Service Ticket 是否一次性使用？ |
| CA2 | `service` 参数是否白名单校验？ |
| CA3 | ST 校验是否通过后端通道（非前端重定向）？ |
| CA4 | 是否存在 CAS 票据重放攻击？ |
| CA5 | Proxy Ticket 链路是否完整校验？ |

### Shiro

| 检查项 | 说明 |
|--------|------|
| SH1 | RememberMe 密钥是否硬编码（默认 `kPH+bIxk5D2deZiIxcaaaA==`）？ |
| SH2 | 是否存在 Shiro-550 反序列化漏洞？ |
| SH3 | 路径匹配是否存在绕过（`/admin/..;/`、`/admin/`、`/admin`）？ |
| SH4 | `anon` 过滤器配置是否过宽？ |
| SH5 | Session 管理是否安全（HttpOnly、Secure、SameSite）？ |

### Spring Security

| 检查项 | 说明 |
|--------|------|
| SS1 | Security Filter Chain 顺序是否正确？ |
| SS2 | `antMatchers` / `requestMatchers` 是否存在绕过？ |
| SS3 | CSRF 保护是否被 `disable()`？ |
| SS4 | CORS 配置是否过宽（`allowedOrigins("*")` + `allowCredentials(true)`）？ |
| SS5 | 是否存在 `permitAll()` 过宽配置？ |
| SS6 | 密码编码器是否安全（BCrypt/Argon2 而非 MD5/SHA）？ |
| SS7 | Session Fixation 防护是否启用？ |
| SS8 | Security Headers 是否配置（X-Frame-Options, CSP, HSTS）？ |

### JWT 高级

| 检查项 | 说明 |
|--------|------|
| JW1 | 是否存在 `alg: none` 攻击？ |
| JW2 | 是否存在 `alg` 混淆（RS256 → HS256 使用公钥签名）？ |
| JW3 | `kid` 参数是否可注入（SQL注入/路径穿越）？ |
| JW4 | `jku` / `jwk` / `x5u` 是否可被劫持？ |
| JW5 | 签名密钥是否过短（< 256 bit）或硬编码？ |
| JW6 | `exp` / `nbf` / `iat` 是否校验？ |
| JW7 | 是否存在 JWT 重放攻击（缺少 `jti` 校验）？ |

## 危险模式

```java
// OAuth2 redirect_uri 绕过
String redirectUri = request.getParameter("redirect_uri");
if (redirectUri.startsWith("https://example.com")) {  // 可被 https://example.com.evil.com 绕过
    response.sendRedirect(redirectUri);
}

// Shiro 硬编码密钥
byte[] key = Base64.decode("kPH+bIxk5D2deZiIxcaaaA==");  // 默认密钥
CookieRememberMeManager rememberMeManager = new CookieRememberMeManager();
rememberMeManager.setCipherKey(key);

// JWT alg: none
String alg = jwt.getHeader().getAlgorithm();
if (alg.equals("none")) {
    // 接受无签名 token
}

// SAML XXE
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
// 未禁用外部实体
Document doc = dbf.newDocumentBuilder().parse(samlResponse);
```

## 审计流程

```
1. 识别项目使用的认证框架/协议
2. 根据协议类型加载对应检查点
3. 检查认证流程实现（登录、授权、Token 校验）
4. 检查密钥/凭证管理
5. 检查 Session 管理
6. 使用 LSP 追踪认证链路
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- Token 校验逻辑在自定义 Filter 中 → 请求展开 Filter 逻辑
- 认证配置在 XML/YAML 中 → 请求读取配置文件
- 密钥来自配置中心 → 追踪密钥管理方式

## 输出格式

```json
{
  "branch": "auth-protocol",
  "protocol": "OAuth2",
  "findings": [
    {
      "type": "OAuth2 redirect_uri 校验不严格",
      "severity": "HIGH",
      "sink": "OAuthController.java:45",
      "source": "OAuthController.java:38 @RequestParam redirect_uri",
      "evidence": "redirectUri.startsWith(\"https://example.com\")  // 可被子域名绕过",
      "sanitization": "仅前缀匹配，未使用精确匹配",
      "poc": "GET /oauth/authorize?redirect_uri=https://example.com.evil.com/callback"
    }
  ]
}
```
