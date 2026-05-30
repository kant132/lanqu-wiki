# 业务协议安全审计清单库 — 索引

## 核心原则

传统 Source→Sink 污点追踪只能发现**技术漏洞**（SQLi/XSS/XXE）。
**业务协议漏洞**需要理解协议的完整流程，逐步验证实现是否偏离安全规范。

## 审计流程

```
1. 协议识别：扫描代码特征，识别项目使用了哪些业务协议
2. 加载清单：对每个识别到的协议，加载对应的子文件
3. 逐项审计：对清单中的每个检查项，在代码中验证是否实现
4. 输出结果：每个检查项输出 PASS/FAIL + 证据 + 风险
```

## 协议文件索引

### 认证与授权协议

| 文件 | 包含协议 | 协议ID |
|------|----------|--------|
| `oauth2.md` | OAuth2 授权码/隐式/PKCE/客户端凭证/刷新令牌 + OIDC | OAUTH2-AC, OAUTH2-IM, OAUTH2-PKCE, OAUTH2-CC, OAUTH2-RT, OIDC |
| `authentication.md` | 密码重置、邮箱验证、多因素认证 | PWD-RESET, EMAIL-VERIFY, MFA |

### 业务交易协议

| 文件 | 包含协议 | 协议ID |
|------|----------|--------|
| `payment.md` | 支付/交易流程 | PAYMENT |

### 数据处理协议

| 文件 | 包含协议 | 协议ID |
|------|----------|--------|
| `data-handling.md` | 文件上传下载、GraphQL、WebSocket | FILE-UPLOAD, GRAPHQL, WEBSOCKET |

### 令牌与凭证

| 文件 | 包含协议 | 协议ID |
|------|----------|--------|
| `jwt.md` | JWT 令牌生命周期 | JWT-LIFECYCLE |

### 基础设施安全

| 文件 | 包含协议 | 协议ID |
|------|----------|--------|
| `infrastructure-crypto.md` | 密码算法、密钥管理、加密模式 | CRYPTO-ALG, CRYPTO-KEY, CRYPTO-MODE |
| `infrastructure-network.md` | TLS/SSL、端口安全、Socket、HTTP 安全 | TLS-SSL, NET-PORT, NET-SOCKET, HTTP-SEC |
| `infrastructure-session.md` | 会话管理、Cookie 安全、Session 存储 | SESSION-MGMT, COOKIE-SEC, SESSION-STORE |
| `infrastructure-api.md` | API 网关、CORS、限流 | API-GATEWAY, CORS-CONFIG |

### 框架组件配置深度审计

| 文件 | 包含内容 | 适用 Skill |
|------|----------|-----------|
| `filter-config-deep.md` | SecurityFilterChain 配置安全语义深度审计 | java-filter-audit |
| `interceptor-config-deep.md` | Interceptor 配置安全语义深度审计 | java-interceptor-audit |

## 输出格式

对每个识别到的协议，输出以下格式：

```markdown
### 协议审计: {协议名称} ({协议ID})

**识别依据**: {在代码中发现的识别特征}
**实现位置**: {相关类/配置文件列表}

#### 审计结果

| 检查项 | 审计内容 | 状态 | 证据 | 严重度 | 确定性 | 说明 |
|--------|----------|------|------|--------|--------|------|
| {ID}-01 | {内容} | PASS/FAIL/N/A | {file:line} | {严重度} | {确定性} | {详细说明} |

#### 攻击向量评估

| 攻击向量 | 可利用性 | 前提条件 | PoC 思路 |
|----------|----------|----------|----------|
| {攻击名称} | 可利用/不可利用/需进一步验证 | {前提} | {PoC} |
```

## 确定性标注

| 检查类型 | 确定性 | 说明 |
|----------|--------|------|
| 配置项检查（如 PKCE 是否启用） | DETERMINISTIC | 配置值明确 |
| 代码模式匹配（如 SecureRandom vs Random） | DETERMINISTIC | 正则匹配 |
| 逻辑完整性验证（如 state 是否被验证） | HEURISTIC | 需追踪代码逻辑 |
| 业务合理性评估（如超时时间是否合理） | SUBJECTIVE | 需安全专家判断 |
| 攻击可利用性评估 | HEURISTIC | 需结合运行时环境 |
