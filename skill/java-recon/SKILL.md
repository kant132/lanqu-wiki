---
name: java-recon
description: Java 项目侦察与资产台账建立。当需要识别 Java 项目的技术栈、路由引擎、Filter/Interceptor 清单时加载。Use when scanning Java project structure, identifying frameworks, filters, interceptors, or building asset inventory.
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Phase 1: 项目分析初始化与组件拓扑识别

## 输出语言规则

所有报告内容必须使用中文输出。标题、描述、分析文字、表头、结论均使用中文。以下内容保持英文：代码片段、文件路径、类名、方法名、技术状态码（PASS/FAIL/N/A）。

## 输入

- 项目根路径

## 输出

- Asset-Inventory JSON（符合 `shared-contracts.md` 协议）

## 门禁断言清单

| 断言  | 含义      | 触发条件                                                                             |
| --- | ------- | -------------------------------------------------------------------------------- |
| C1  | 依赖完整性   | pom.xml 或 build.gradle 存在且可解析                                                    |
| C2  | 全引擎组件识别 | 扫描并精准记录所有路由引擎（Spring WebMVC, JAX-RS/Jersey, Struts2, Native Servlet, Dubbo/gRPC） |
| C3  | 资产台账已建立 | Filters.size() + Interceptors.size() >= 0                                        |
| C4  | 组件注册全覆盖 | 交叉检索XML配置、类注解及配置类，建立资产总表                                                         |
| C5  | 版本号精准感知 | 识别核心框架版本，为后续特定版本行为提供判定基准                                                         |
| C6  | 配置文件深度分析 | 解析 application.yml/properties 等配置文件，提取安全相关配置项，标注风险等级                                    |
| C7  | 启动时安全配置提取 | 扫描 @Configuration @Bean、@PostConstruct、ApplicationRunner 等启动时安全初始化逻辑，建立安全 Bean 资产清单        |
| C8  | 业务协议资产识别 | 扫描项目使用的业务安全协议（OAuth2/SAML/支付/密码重置/MFA/JWT/Session/TLS/密码算法等），建立协议资产清单，为后续协议级审计提供输入。协议审计清单详见 java-api-audit/references/protocols/ 目录 |

## 执行流程

### Step 1: 构建文件解析（C1, C5）

```
1. 定位 pom.xml 或 build.gradle
2. 提取核心依赖及版本号
3. 识别框架类型：
   - spring-boot-starter-web → Spring MVC
   - spring-boot-starter-webflux → Spring WebFlux
   - struts2-core → Struts2
   - jersey-server → JAX-RS
   - dubbo → Dubbo RPC
4. 若构建文件不存在 → 触发 ERR-NO-BUILD
```

### Step 2: 路由引擎识别（C2）

针对每种引擎执行特征扫描：

| 引擎 | 扫描目标 |
|------|----------|
| Spring MVC | `@Controller`, `@RestController`, `@RequestMapping` |
| JAX-RS | `@Path`, `@GET`, `@POST` |
| Struts2 | `struts.xml`, `@Action` |
| Native Servlet | `@WebServlet`, `web.xml <servlet>` |
| Dubbo | `@DubboService`, `@DubboReference` |

### Step 3: Filter 资产提取

```
扫描目标：
- @WebFilter 注解类
- web.xml <filter> + <filter-mapping>
- FilterRegistrationBean 注册
- Spring Security FilterChain 配置

提取字段：class, url_patterns, order, dispatcher_types
```

### Step 4: Interceptor 资产提取

```
扫描目标：
- HandlerInterceptor 实现类
- WebMvcConfigurer.addInterceptors()
- XML <mvc:interceptors>

提取字段：class, include_patterns, exclude_patterns
```

### Step 5: 配置源交叉验证（C4）

```
交叉检索：
- Java Config 类（@Configuration）
- XML 配置文件
- application.yml / application.properties
- 注解扫描

确保每个组件至少在一个配置源中被注册。
```

### Step 6: Application 配置文件深度分析（C6）

```
扫描目标：
- application.yml / application.yaml
- application.properties
- application-{profile}.yml / application-{profile}.properties
- bootstrap.yml / bootstrap.properties
- 自定义配置文件（通过 @PropertySource 引入）

提取以下安全相关配置：

1. 认证与授权配置:
   - security.* 相关配置项
   - oauth2.* / jwt.* 配置
   - 自定义认证开关/白名单路径

2. 数据源配置:
   - spring.datasource.* (URL、用户名、连接池)
   - 多数据源配置
   - MyBatis/Hibernate 配置（是否开启 ${} 拼接）

3. 文件上传配置:
   - spring.servlet.multipart.* (大小限制、临时目录)
   - 自定义文件存储路径

4. 日志配置:
   - logging.level.* (是否开启 DEBUG 导致信息泄露)
   - 日志输出路径

5. Actuator 配置:
   - management.endpoints.* (暴露的端点)
   - management.server.port (管理端口)

6. 自定义业务配置:
   - 业务白名单/黑名单
   - API 密钥/Token 配置
   - 第三方服务 URL
   - 加密/签名开关

7. CORS 配置:
   - 允许的 Origin/Method/Header
   - 是否允许 Credentials

8. 序列化配置:
   - Jackson/Fastjson 配置（是否开启 autoType）
   - 自定义序列化器

输出要求：
- 每个配置项记录：配置键、配置值、所在文件、行号
- 标注安全风险等级（HIGH/MEDIUM/LOW）
- 配置值中的敏感信息（密码、密钥）标记为 [REDACTED]
```

### Step 7: 启动时安全配置资产提取（C7）

```
扫描目标：
- @Configuration 类中定义的安全相关 @Bean
- @PostConstruct 方法中的安全初始化逻辑
- ApplicationRunner / CommandLineRunner 实现类
- ApplicationListener<ApplicationReadyEvent> / ApplicationListener<ContextRefreshedEvent>
- @Import / @ImportResource 引入的安全配置
- Spring Boot Auto-configuration 排除项（@SpringBootApplication.exclude）

提取以下安全 Bean 资产：

1. 认证相关 Bean:
   - PasswordEncoder @Bean（类型、所在类:行号）
   - UserDetailsService @Bean
   - AuthenticationProvider @Bean
   - AuthenticationManager @Bean

2. Token/JWT 相关 Bean:
   - JWT 签名/验证配置
   - Token 生成器/验证器
   - OAuth2 客户端配置

3. 安全基础设施 Bean:
   - CorsConfigurationSource @Bean
   - SessionRegistry @Bean
   - SecurityFilterChain @Bean（已在 Step 3 提取，此处交叉验证）

4. 数据初始化:
   - ApplicationRunner / CommandLineRunner 中的数据初始化
   - @PostConstruct 中的默认用户/权限创建
   - schema.sql / data.sql / Flyway / Liquibase 迁移脚本

5. 第三方集成:
   - RestTemplate / WebClient @Bean
   - 消息队列连接配置
   - 缓存管理器配置

输出要求：
- 每个 Bean 记录：Bean 名称、类型、所在类:行号、安全相关性
- 标注 Bean 的安全影响等级（HIGH/MEDIUM/LOW）
- 交叉验证：Bean 定义是否与 application.yml 配置一致
```

### Step 8: 业务协议资产识别（C8）

```
扫描项目使用的业务安全协议，建立协议资产清单。
这是后续"协议级审计"的基础——不理解业务协议，就无法发现协议实现中的安全缺陷。

扫描目标（按协议类型）：

1. OAuth2/OIDC 协议:
   - 依赖: spring-boot-starter-oauth2-client, spring-boot-starter-oauth2-resource-server, nimbus-jose-jwt
   - 注解: @EnableOAuth2Client, @EnableOAuth2Sso, @EnableResourceServer
   - 配置: spring.security.oauth2.client.*, spring.security.oauth2.resourceserver.*
   - 类: OAuth2AuthorizedClient, JwtDecoder, OidcUserService
   - 端点: /oauth2/authorization/*, /login/oauth2/code/*

2. SAML 协议:
   - 依赖: spring-security-saml2-service-provider, opensaml
   - 类: SAMLAuthenticationProvider, RelyingPartyRegistration
   - 端点: /saml2/authenticate/*, /login/saml2/*

3. 密码重置流程:
   - 方法名: resetPassword, forgotPassword, sendResetLink, changePassword
   - 端点路径: /reset*, /forgot*, /password-reset*
   - 参数: resetToken, resetLink, email, newPassword

4. 多因素认证(MFA):
   - 关键词: twoFactor, mfa, otp, totp, authenticator, smsCode
   - 依赖: commons-codec (TOTP), google-authenticator

5. 支付/交易流程:
   - 关键词: payment, charge, transfer, transaction, order, checkout, amount
   - 端点: /pay, /checkout, /transfer, /order/create

6. JWT 令牌管理:
   - 依赖: jjwt, java-jwt, jose4j, nimbus-jose-jwt
   - 类: Jwt, JwtDecoder, JwtEncoder
   - 配置: jwt.secret, jwt.expiration

7. WebSocket 通信:
   - 注解: @ServerEndpoint, @MessageMapping, @EnableWebSocketMessageBroker
   - 类: WebSocketHandler, StompEndpointConfigurer

8. GraphQL API:
   - 依赖: graphql-java, graphql-spring-boot, dgs-framework
   - 注解: @QueryMapping, @MutationMapping, @DgsQuery
   - 端点: /graphql, /graphiql

9. 文件上传/下载:
   - 类: MultipartFile, Part
   - 端点: /upload, /download, /file, /attachment

10. 会话管理:
    - 配置: server.servlet.session.*, spring.session.*
    - 类: HttpSession, SessionRegistry

11. 密码算法与密钥管理:
    - 类: MessageDigest, Cipher, SecretKeyFactory, KeyGenerator, Signature
    - 配置: *.secret, *.key, *.password 在 application.yml 中
    - 依赖: bouncy-castle, jose4j, nimbus-jose-jwt

12. TLS/SSL 配置:
    - 配置: server.ssl.*, server.http2.*
    - 类: SSLContext, SSLSocketFactory, TrustManager, X509TrustManager
    - 依赖: netty (WebFlux), undertow

13. 网络端口与 Socket:
    - 配置: server.port, management.server.port, server.address
    - 类: ServerSocket, Socket, SocketChannel, @ServerEndpoint
    - 依赖: netty, undertow, tomcat

14. API 网关与限流:
    - 依赖: spring-cloud-gateway, zuul, bucket4j, resilience4j
    - 注解: @RateLimiter, @Throttle
    - 配置: spring.cloud.gateway.*

输出要求：
- 每个识别到的协议记录：协议ID、协议名称、识别依据（依赖/注解/配置/类/端点）、实现位置（文件:行号）
- 标注协议的安全关键度（CRITICAL/HIGH/MEDIUM）
- 输出格式：

| 协议ID | 协议名称 | 识别依据 | 实现位置 | 安全关键度 |
|--------|----------|----------|----------|-----------|
| OAUTH2-AC | OAuth2 授权码流程 | spring-boot-starter-oauth2-client + @EnableOAuth2Client | WebSecurityConfig.java:45 | CRITICAL |
| JWT-LIFECYCLE | JWT 令牌生命周期 | jjwt 0.9.1 + JwtDecoder | JwtConfig.java:12 | CRITICAL |
| PWD-RESET | 密码重置流程 | resetPassword() + /password-reset 端点 | UserController.java:78 | HIGH |
```

## 强制输出模板

> 详细输出模板见 [`references/phase1-init-output.md`](references/phase1-init-output.md)

## 输出示例

```json
{
  "project_meta": {
    "framework": "Spring Boot",
    "version": "3.2.0",
    "build_tool": "Maven"
  },
  "engines": ["Spring MVC"],
  "filters": [
    {
      "id": "FILTER-001",
      "class": "com.example.AuthFilter",
      "url_patterns": ["/api/*"],
      "order": 1
    }
  ],
  "interceptors": [
    {
      "id": "INTC-001",
      "class": "com.example.LoginInterceptor",
      "include_patterns": ["/**"],
      "exclude_patterns": ["/login", "/static/**"]
    }
  ],
  "config_sources": ["WebMvcConfig.java", "application.yml"],
  "warnings": []
}
```
