# 网络与传输安全审计清单

## TLS-SSL: TLS/SSL 配置安全

**识别特征:** `SSLContext`, `TLSv`, `server.ssl.*`, `https`, `SSLSocketFactory`, `TrustManager`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CTLS-01 | TLS 版本 | 必须使用 TLS 1.2+，禁止 SSLv3/TLS 1.0/TLS 1.1 | 检查 `server.ssl.enabled-protocols` 配置 | CRITICAL |
| CTLS-02 | 密码套件 | 禁用弱密码套件（RC4, DES, EXPORT, NULL, anon） | 检查 `server.ssl.ciphers` 配置 | HIGH |
| CTLS-03 | 证书有效性 | 生产环境必须使用有效 CA 签发的证书，禁止自签名 | 检查 `server.ssl.key-store` 配置 | HIGH |
| CTLS-04 | HSTS | 应配置 `Strict-Transport-Security` 头 | 检查是否配置 HSTS | MEDIUM |
| CTLS-05 | 证书固定 | 高安全场景应实现证书固定(Certificate Pinning) | 检查是否有 `CertificatePinner` | LOW |
| CTLS-06 | 客户端证书 | 双向 TLS 场景应正确验证客户端证书 | 检查 `client-auth=need/want` 配置 | MEDIUM |
| CTLS-07 | SSL 禁用 | 生产环境禁止 `server.ssl.enabled=false` | 检查配置文件中的 `ssl.enabled` | CRITICAL |
| CTLS-08 | 信任管理器 | 禁止自定义 `TrustManager` 信任所有证书 | 搜索 `X509TrustManager` 空实现 | CRITICAL |
| CTLS-09 | OCSP/CRL | 应启用证书吊销检查 | 检查是否配置 OCSP/CRL | LOW |
| CTLS-10 | SNI | 多域名场景应正确配置 SNI | 检查 SNI 配置 | LOW |

---

## NET-PORT: 端口与网络暴露安全

**识别特征:** `server.port`, `management.server.port`, `@ServerEndpoint`, `ServerSocket`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CPORT-01 | 管理端口隔离 | Actuator/管理端口应与业务端口隔离，且限制访问 | 检查 `management.server.port` 配置 | HIGH |
| CPORT-02 | 端口暴露 | 生产环境禁止暴露调试端口（JMX、JDB、RMI） | 搜索 JMX/RMI 相关配置 | CRITICAL |
| CPORT-03 | 绑定地址 | 生产环境禁止绑定 `0.0.0.0`，应绑定具体 IP | 检查 `server.address` 配置 | HIGH |
| CPORT-04 | 端口扫描防护 | 应关闭不必要的端口和服务 | 检查开放的端口列表 | MEDIUM |
| CPORT-05 | AJP 连接器 | 如使用 AJP，必须配置 secret 防止 Ghostcat 漏洞 | 检查 AJP connector 配置 | HIGH |
| CPORT-06 | HTTP/2 | 如启用 HTTP/2，应确认无已知漏洞 | 检查 `server.http2.enabled` | LOW |
| CPORT-07 | 优雅关闭 | 应配置优雅关闭，防止请求中断导致数据不一致 | 检查 `server.shutdown=graceful` | LOW |

---

## NET-SOCKET: Socket 通信安全

**识别特征:** `ServerSocket`, `Socket`, `SocketChannel`, Netty, `@ServerEndpoint`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CSOCK-01 | Socket 认证 | Socket 通信应有身份认证机制 | 检查 Socket 连接后是否有认证握手 | HIGH |
| CSOCK-02 | Socket 加密 | Socket 通信应使用 SSL/TLS 加密 | 检查是否使用 `SSLSocket`/`SSLEngine` | HIGH |
| CSOCK-03 | 输入验证 | Socket 接收的数据必须经过输入验证 | 检查 Socket 读取后的数据处理 | HIGH |
| CSOCK-04 | 连接限制 | 应限制最大并发连接数，防止 DoS | 检查 `ServerSocket` backlog/连接池配置 | MEDIUM |
| CSOCK-05 | 超时设置 | Socket 必须设置读写超时，防止资源耗尽 | 检查 `setSoTimeout`/`setReadTimeout` | MEDIUM |
| CSOCK-06 | 缓冲区溢出 | 应限制单次读取的数据大小 | 检查读取缓冲区大小限制 | HIGH |

---

## HTTP-SEC: HTTP 安全配置

**识别特征:** `server.compression`, `server.http2`, `Strict-Transport-Security`, `X-Frame-Options`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CHTTP-01 | HTTP 重定向 | HTTP 应自动重定向到 HTTPS | 检查是否有 HTTP→HTTPS 重定向配置 | HIGH |
| CHTTP-02 | 安全头 | 必须配置 `X-Frame-Options`, `X-Content-Type-Options`, CSP | 检查 `headers()` 配置 | HIGH |
| CHTTP-03 | 服务器信息泄露 | 禁止在响应头中暴露服务器版本（`Server: Apache/2.4`） | 检查 `server.error.include-stacktrace`, Server header | MEDIUM |
| CHTTP-04 | 请求大小限制 | 必须限制请求体/请求头大小 | 检查 `server.max-http-header-size`, `spring.servlet.multipart.max-file-size` | MEDIUM |
| CHTTP-05 | HTTP 方法限制 | 应仅允许必要的 HTTP 方法 | 检查是否有方法限制配置 | MEDIUM |
| CHTTP-06 | 错误页面 | 自定义错误页面不得泄露技术细节 | 检查 `ErrorController` 实现 | MEDIUM |
| CHTTP-07 | 压缩安全 | HTTPS + 压缩可能受 BREACH 攻击，敏感响应应禁用压缩 | 检查 `server.compression` 配置 | LOW |
| CHTTP-08 | 请求走私 | 应防止 HTTP 请求走私（CL/TE 不一致） | 检查反向代理配置 | HIGH |
