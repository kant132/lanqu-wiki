# 数据处理协议安全审计清单

## FILE-UPLOAD: 文件上传下载

### 识别特征

```
类: MultipartFile, Part, CommonsMultipartFile
端点: /upload, /file, /attachment, /import
配置: spring.servlet.multipart.*, multipart.*
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| FU-01 | 文件类型校验 | 必须校验文件 MIME 类型和扩展名，使用白名单 | 检查文件类型校验逻辑；是否同时校验 Content-Type 和文件头（magic bytes） | HIGH |
| FU-02 | 文件大小限制 | 必须配置文件大小限制，防止 DoS | 检查 spring.servlet.multipart.max-file-size 配置 | MEDIUM |
| FU-03 | 文件名安全 | 存储文件名不得直接使用原始文件名，应使用 UUID 重命名 | 检查文件名处理逻辑；是否使用 getOriginalFilename() 直接作为存储名 | CRITICAL |
| FU-04 | 路径穿越防护 | 文件存储路径不得包含用户输入，防止路径穿越 | 检查 new File() 的参数；是否有 canonical path 校验 | CRITICAL |
| FU-05 | 文件内容校验 | 上传的文件内容应与其声明的类型一致（防止伪装） | 检查是否读取文件头（magic bytes）验证实际类型 | HIGH |
| FU-06 | 执行权限 | 上传目录不得有执行权限，防止上传 WebShell | 检查上传目录的配置；是否在 Web 根目录下；是否有执行权限 | CRITICAL |
| FU-07 | 下载权限控制 | 文件下载接口必须验证用户对文件的访问权限 | 检查下载接口是否有权限校验；是否存在 IDOR | HIGH |
| FU-08 | 病毒扫描 | 生产环境应对上传文件进行病毒扫描 | 检查是否有病毒扫描集成（ClamAV 等） | MEDIUM |
| FU-09 | ZIP Slip | 解压 ZIP 文件时必须校验每个条目的路径，防止路径穿越 | 检查 ZipEntry.getName() 的使用；是否有 ../ 校验 | CRITICAL |

---

## GRAPHQL: GraphQL API

### 识别特征

```
库: graphql-java, graphql-spring-boot, DGS Framework
注解: @QueryMapping, @MutationMapping, @SchemaMapping, @DgsQuery, @DgsMutation
端点: /graphql, /graphiql, /playground
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| GQL-01 | 查询深度限制 | 必须限制查询深度，防止深层嵌套导致 DoS | 检查 MaxQueryDepthInstrumentation 配置 | HIGH |
| GQL-02 | 查询复杂度限制 | 必须限制查询复杂度（节点数/字段数），防止资源耗尽 | 检查 MaxQueryComplexityInstrumentation 配置 | HIGH |
| GQL-03 | 内省(Introspection)控制 | 生产环境应禁用内省查询，防止 Schema 泄露 | 检查 Introspection 是否在生产环境禁用 | MEDIUM |
| GQL-04 | 批量查询滥用 | 应限制单次请求中的查询数量（防止 Batch Query Attack） | 检查是否有批量查询限制 | HIGH |
| GQL-05 | 字段级权限控制 | 敏感字段应有独立的权限检查，不得仅依赖查询级权限 | 检查 @DgsData 或 DataFetcher 中的权限校验 | HIGH |
| GQL-06 | 错误信息泄露 | GraphQL 错误响应不得泄露内部实现（SQL 错误、堆栈跟踪） | 检查 GraphQLErrorHandler 实现；检查错误消息内容 | MEDIUM |
| GQL-07 | Mutation CSRF 防护 | Mutation 操作必须有 CSRF 防护（GraphQL 通常通过 POST 发送） | 检查 Mutation 端点是否有 CSRF token 验证 | HIGH |
| GQL-08 | 参数注入 | GraphQL 变量（variables）应使用参数化方式，不得拼接到查询字符串中 | 检查查询构建方式；是否使用变量绑定 | HIGH |

---

## WEBSOCKET: WebSocket 通信

### 识别特征

```
注解: @ServerEndpoint, @MessageMapping, @SubscribeMapping
类: WebSocketHandler, TextWebSocketHandler, StompEndpointConfigurer
配置: WebSocketConfigurer, registerStompEndpoints
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| WS-01 | Origin 校验 | WebSocket 握手必须验证 Origin header，防止跨站 WebSocket 劫持 | 检查 setAllowedOrigins 配置；是否使用 * | CRITICAL |
| WS-02 | 认证集成 | WebSocket 连接必须与 Spring Security 集成，验证用户身份 | 检查握手拦截器中是否有认证逻辑；检查 STOMP 是否配置了 ChannelInterceptor | HIGH |
| WS-03 | 消息授权 | WebSocket 消息应有细粒度授权（谁可以发送到哪个目标） | 检查 @SendToUser / SimpMessagingTemplate 的权限控制 | HIGH |
| WS-04 | 输入验证 | WebSocket 消息内容必须经过输入验证（与 HTTP 请求同等） | 检查 @MessageMapping 方法的参数校验 | HIGH |
| WS-05 | 消息大小限制 | 必须限制 WebSocket 消息大小，防止内存耗尽 | 检查 setMessageSizeLimit 配置 | MEDIUM |
| WS-06 | 速率限制 | 应限制 WebSocket 消息发送频率 | 检查是否有消息频率限制 | MEDIUM |
| WS-07 | CSRF via WebSocket | STOMP over WebSocket 应有 CSRF 防护（CSRF token 验证） | 检查 CsrfChannelInterceptor 配置 | HIGH |
