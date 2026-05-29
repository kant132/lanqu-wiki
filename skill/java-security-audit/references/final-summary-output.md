# 最终报告输出模板

所有阶段报告及最终报告必须输出到 `output/` 目录，格式统一为 Markdown。

## 边界规则

- **最终报告**（output/final-audit-report.md）：只含统计数字、断言汇总表、漏洞清单（一行一条）、修复建议、资产守恒验证
- **阶段报告**（output/phase*.md）：含详细正向链路、PoC、代码证据、业务影响
- **禁止重复**：最终报告不得包含正向链路细节、PoC、代码证据 — 这些在 phase4-api-audit.md 中
- **禁止解释**：资产守恒验证只输出 PASS/FAIL + 缺失数，不得附加解释性文字

## 最终报告结构

```markdown
# Java 正向安全审计报告

## 0. 执行摘要

| 项目 | 内容 |
|------|------|
| 项目路径 | {path} |
| 技术栈 | {framework} {version} |
| 审计时间 | {timestamp} |
| 整体风险等级 | CRITICAL / HIGH / MEDIUM / LOW |
| 漏洞总数 | {total} |
| 业务风险数 | {business_count} |
| 技术风险数 | {technical_count} |
| 配置风险数 | {config_count} |

## 1. 审计元数据

| 项目 | 内容 |
|------|------|
| 构建文件 | pom.xml / build.gradle |
| 路由引擎 | {engines} |
| 审计范围 | 框架分析 + API分析 + 启动配置分析 + 综合分析 |

## 2. 框架分析结果（Part 1）

### 2.1 资产统计

| 类型 | 数量 |
|------|------|
| 路由引擎 | {engines_count} |
| 自定义 Filter | {filters_count} |
| Filter 注册配置 | {filter_registrations_count} |
| SecurityFilterChain | {security_configs_count} |
| Interceptor | {interceptors_count} |
| 启动安全配置 Bean | {startup_security_beans_count} |

### 2.2 Filter/Interceptor 执行链

```
Request → Filter1(order=1) → Filter2(order=2) → DispatcherServlet → Interceptor1(order=1) → Interceptor2(order=2) → Controller
```

| 执行顺序 | 组件类型 | 组件名 | URL 模式 | 注册方式 | 保护层级 |
|----------|----------|--------|----------|----------|----------|
| 1 | Filter | AuthFilter | /api/* | FilterRegistrationBean | 认证 |
| 2 | SecurityFilterChain | Spring Security | /** | @Bean | 全局安全 |
| 3 | Interceptor | AuthInterceptor | /api/** | addInterceptors | Token校验 |

### 2.3 Filter 类代码审计（P1-P7）

| 断言 | 目标 | 状态 | 证据 | 可达性 | 调整后严重度 |
|------|------|------|------|--------|-------------|
| P1 | {target} | PASS/FAIL | {file:line} | REACHABLE/... | HIGH/... |

### 2.4 Filter 注册配置审计（FC1-FC6）

| 断言 | 目标 | 状态 | 证据 | 可达性 | 调整后严重度 |
|------|------|------|------|--------|-------------|
| FC1 | {target} | PASS/FAIL | {file:line} | REACHABLE/... | HIGH/... |

### 2.5 SecurityFilterChain 配置审计（SC1-SC10）

| 断言 | 目标 | 状态 | 证据 | 可达性 | 调整后严重度 |
|------|------|------|------|--------|-------------|
| SC1 | {target} | PASS/FAIL | {file:line} | REACHABLE/... | HIGH/... |

### 2.6 Interceptor 审计

| 断言 | 目标 | 状态 | 证据 | 可达性 | 调整后严重度 |
|------|------|------|------|--------|-------------|
| I1 | {target} | PASS/FAIL | {file:line} | REACHABLE/... | HIGH/... |

### 2.7 启动时安全配置审计（BC1-BC8）

| 断言 | 目标 Bean | 类型 | 状态 | 证据 | 严重度 |
|------|----------|------|------|------|--------|
| BC1 | {bean_name} | AuthenticationProvider | PASS/FAIL | {file:line} | HIGH/... |

### 2.8 可达性评估汇总

| 漏洞ID | 原始严重度 | 可达性 | 调整后严重度 | 理由 |
|--------|-----------|--------|-------------|------|
| H-FI-001 | HIGH | UNREACHABLE | INFO | 被前置 AuthFilter 拦截 |
| H-IN-001 | HIGH | PARTIALLY_REACHABLE | MEDIUM | 仅已认证用户可触发 |

## 3. API 分析结果（Part 2）

### 3.1 路由统计

| 指标 | 数量 |
|------|------|
| 总端点数 | {total_endpoints} |
| CRITICAL 端点 | {critical_count} |
| HIGH 端点 | {high_count} |
| MEDIUM 端点 | {medium_count} |

### 3.2 漏洞清单（一行一条，不含详情）

| # | 类型 | 严重度 | 端点 | 位置 |
|---|------|--------|------|------|
| 1 | SQL注入 | CRITICAL | POST /api/users | SqlInjectionLesson8.java:49 |

> 详细正向链路、PoC、业务影响见 output/phase4-api-audit.md

## 4. 综合安全分析（Part 3）

> 详见 output/comprehensive-security-analysis.md

### 4.1 业务安全风险 Top 5

| # | 业务场景 | 风险类型 | 严重度 | 业务影响 |
|---|----------|----------|--------|----------|
| 1 | {场景} | {类型} | {严重度} | {影响} |

### 4.2 技术安全风险 Top 5

| # | 漏洞类型 | 数量 | 最高严重度 | 系统性风险 |
|---|----------|------|-----------|-----------|
| 1 | {类型} | {数量} | {严重度} | {风险} |

### 4.3 配置安全风险 Top 5

| # | 配置类别 | 配置项 | 风险等级 | 影响范围 |
|---|----------|--------|----------|----------|
| 1 | {类别} | {配置项} | {等级} | {范围} |

### 4.4 交叉关联复合风险

| # | 复合风险描述 | 涉及维度 | 综合严重度 | 攻击链 |
|---|-------------|----------|-----------|--------|
| 1 | {描述} | 业务+技术+配置 | CRITICAL | {攻击链} |

### 4.5 攻击面总览

| 攻击面类型 | 入口点数量 | 最高风险 | 关键发现 |
|-----------|-----------|----------|----------|
| 外部攻击面 | {count} | {risk} | {finding} |
| 内部攻击面 | {count} | {risk} | {finding} |
| 配置攻击面 | {count} | {risk} | {finding} |
| 供应链攻击面 | {count} | {risk} | {finding} |

## 5. 修复建议

### 5.1 业务层修复建议
1. ...

### 5.2 技术层修复建议
1. ...

### 5.3 配置层修复建议
1. ...

## 6. 资产守恒验证

| 项目 | 数量 |
|------|------|
| Phase 1 发现资产总数 | {total} |
| Phase 2/3 审计资产数 | {audited} |
| 缺失资产 | {missing} |
| 守恒验证 | PASS / FAIL |
```

## 中间输出文件规范

### output/phase1-recon.md

```markdown
# Phase 1: 项目初始化报告

## 项目元数据
- 框架: {framework}
- 版本: {version}
- 构建工具: {build_tool}

## 资产台账
### 路由引擎
- {engine_name}

### Filter
| ID | 类名 | URL模式 | 顺序 |
|----|------|---------|------|
| FILTER-001 | com.example.AuthFilter | /api/* | 1 |

### SecurityFilterChain
| ID | 配置类 | CSRF | permitAll 路径 | 密码编码器 |
|----|--------|------|---------------|-----------|
| SEC-CONFIG-001 | WebSecurityConfig | disabled | /css/**, /actuator/** | NoOpPasswordEncoder |

### Interceptor
| ID | 类名 | 包含模式 | 排除模式 |
|----|------|----------|----------|
| INTC-001 | LoginInterceptor | /** | /login, /static/** |

## 配置文件分析（Config_Analysis）

### 扫描的配置文件
| 文件路径 | Profiles |
|----------|----------|
| src/main/resources/application.yml | default, dev, prod |
| src/main/resources/application-dev.yml | dev |

### 安全相关配置
| 配置键 | 配置值 | 文件 | 行号 | 风险等级 | 说明 |
|--------|--------|------|------|----------|------|
| security.jwt.secret | [REDACTED] | application.yml | 45 | HIGH | JWT 密钥硬编码在配置文件中 |
| management.endpoints.web.exposure.include | health,info,env | application.yml | 62 | HIGH | 暴露 env 端点可能泄露敏感配置 |
| cors.allowed-origins | * | application.yml | 70 | HIGH | CORS 允许所有来源 |

### 数据源配置
| 配置键 | 配置值 | 文件 | 行号 | 风险等级 |
|--------|--------|------|------|----------|
| spring.datasource.url | jdbc:mysql://... | application-dev.yml | 12 | LOW |

### 自定义业务配置
| 配置键 | 配置值 | 文件 | 行号 | 风险等级 | 说明 |
|--------|--------|------|------|----------|------|
| csb.gateway.timeout | 30000 | application.yml | 85 | LOW | 云网关超时配置 |

## 依赖拓扑
### 关键依赖
| 依赖 | 版本 | 已知CVE |
|------|------|---------|
| xstream | 1.4.5 | CVE-2013-7285 |

## 断言评估
| 断言 | 状态 | 说明 |
|------|------|------|
| C1: 构建文件存在 | PASS | pom.xml 存在 |
| C2: 路由引擎识别 | PASS | Spring MVC |
| C3: 资产台账非空 | PASS | {count} 个组件 |
| C4: Filter 发现 | PASS/N/A | {count} 个 |
| C5: Interceptor 发现 | PASS/N/A | {count} 个 |
| C6: 配置文件深度分析 | PASS | {count} 个配置项，{high_count} 个 HIGH 风险 |
```

### output/phase2-filter-audit.md

```markdown
# Phase 2: Filter 与安全配置审计报告

## Filter 执行链顺序

| 执行顺序 | Filter ID | 类名 | URL 模式 | Order 值 | 注册方式 | Dispatcher 类型 |
|----------|-----------|------|----------|----------|----------|----------------|
| 1 | FILTER-001 | AuthFilter | /api/* | 1 | FilterRegistrationBean | REQUEST, FORWARD |
| 2 | SEC-CONFIG-001 | Spring Security FilterChain | /** | - | @Bean | REQUEST |

## 审计范围
- 自定义 Filter 类: {count} 个
- Filter 注册配置: {count} 个
- SecurityFilterChain: {count} 个
- web.xml Filter: {count} 个

## 第一层：Filter 类代码审计（P1-P7）

| 断言 | 目标 | 状态 | 证据 | 详情 | 可达性 | 调整后严重度 |
|------|------|------|------|------|--------|-------------|
| P1: Source提取 | FILTER-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |

## 第二层：Filter 注册配置审计（FC1-FC6）

| 断言 | 目标 | 状态 | 证据 | 详情 | 可达性 | 调整后严重度 |
|------|------|------|------|------|--------|-------------|
| FC1: 注册方式一致性 | FILTER-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| FC2: URL模式覆盖完整性 | FILTER-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| FC3: Dispatcher类型 | FILTER-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| FC4: 初始化参数安全 | FILTER-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| FC5: Order值冲突 | 全局 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| FC6: 条件注册 | FILTER-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |

## 第三层：SecurityFilterChain 配置审计（SC1-SC10）

| 断言 | 目标 | 状态 | 证据 | 详情 | 可达性 | 调整后严重度 |
|------|------|------|------|------|--------|-------------|
| SC1: CSRF配置 | SEC-CONFIG-001 | FAIL | WebSecurityConfig.java:61 | csrf.disable() | REACHABLE | HIGH |
| SC2: 认证路径配置 | SEC-CONFIG-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| SC3: 密码编码器 | SEC-CONFIG-001 | FAIL | WebSecurityConfig.java:87 | NoOpPasswordEncoder | REACHABLE | HIGH |
| SC4: CORS配置 | SEC-CONFIG-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| SC5: 会话管理 | SEC-CONFIG-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| SC6: HTTP安全头 | SEC-CONFIG-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| SC7: 认证入口点 | SEC-CONFIG-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| SC8: OAuth2/OIDC配置 | SEC-CONFIG-001 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |
| SC9: Remember-Me | SEC-CONFIG-001 | PASS/FAIL/N/A | {file:line} | {detail} | {reachability} | {severity} |
| SC10: 多SecurityFilterChain | 全局 | PASS/FAIL | {file:line} | {detail} | {reachability} | {severity} |

## 可达性评估详情

| 漏洞ID | 原始严重度 | 可达性 | 调整后严重度 | 前置拦截组件 | 理由 |
|--------|-----------|--------|-------------|-------------|------|
| SC1-SEC-CONFIG-001 | HIGH | REACHABLE | HIGH | 无 | CSRF 禁用影响所有端点，无补偿控制 |

## 熔断记录
| 类型 | 目标 | 严重度 | 影响范围 | 可达性 |
|------|------|--------|----------|--------|
| filter_bypassed | FILTER-001 | ERROR | /api/* | UNREACHABLE (降级为INFO) |
```

### output/phase2b-startup-config-audit.md

```markdown
# Phase 2b: 启动时安全配置审计报告

## 扫描范围
- @Configuration 类: {count} 个
- @Bean 安全组件: {count} 个
- @PostConstruct 初始化: {count} 个
- ApplicationRunner/CommandLineRunner: {count} 个
- ApplicationListener 启动事件: {count} 个

## 安全 Bean 清单

| # | Bean 名称 | 类型 | 所在类:行号 | 安全评估 |
|---|----------|------|------------|----------|
| 1 | passwordEncoder | PasswordEncoder | WebSecurityConfig.java:87 | FAIL: NoOpPasswordEncoder |
| 2 | corsConfigurationSource | CorsConfigurationSource | WebConfig.java:45 | PASS: 限制了 Origin |

## 断言结果（BC1-BC8）

| 断言 | 目标 Bean | 类型 | 状态 | 证据 | 严重度 | 说明 |
|------|----------|------|------|------|--------|------|
| BC1: 认证Provider配置 | userService | UserDetailsService | UserService.java:23 | PASS/FAIL | {severity} | {detail} |
| BC2: Token/JWT配置 | jwtTokenProvider | JwtTokenProvider | JwtConfig.java:34 | PASS/FAIL | {severity} | {detail} |
| BC3: 数据源安全初始化 | dataSource | DataSource | DatabaseConfig.java:12 | PASS/FAIL | {severity} | {detail} |
| BC4: 缓存安全配置 | cacheManager | CacheManager | CacheConfig.java:28 | PASS/FAIL | {severity} | {detail} |
| BC5: 消息队列安全 | rabbitTemplate | RabbitTemplate | MqConfig.java:15 | PASS/FAIL/N/A | {severity} | {detail} |
| BC6: 第三方服务集成 | restTemplate | RestTemplate | WebConfig.java:56 | PASS/FAIL | {severity} | {detail} |
| BC7: 定时任务安全 | scheduledTasks | ScheduledTasks | TaskConfig.java:22 | PASS/FAIL/N/A | {severity} | {detail} |
| BC8: 自定义安全初始化 | securityInitializer | ApplicationRunner | SecurityInit.java:18 | PASS/FAIL | {severity} | {detail} |

## 启动初始化逻辑审计

| # | 执行时机 | 类名:行号 | 功能描述 | 安全影响 | 风险等级 |
|---|----------|----------|----------|----------|----------|
| 1 | @PostConstruct | SecurityInit.java:25 | 创建默认管理员账户 | HIGH: 默认密码 admin/admin | HIGH |
| 2 | ApplicationRunner | DataSeeder.java:15 | 初始化测试数据 | MEDIUM: 包含测试用户凭证 | MEDIUM |

## 与配置文件交叉验证

| 配置项 | 配置文件值 | Bean 定义值 | 一致性 | 风险 |
|--------|-----------|------------|--------|------|
| jwt.secret | ${JWT_SECRET:defaultKey} | 硬编码 "defaultKey" | 不一致 | HIGH: 未读取环境变量 |
```

### output/phase3-interceptor-audit.md

```markdown
# Phase 3: Interceptor 审计报告

## Interceptor 执行链顺序

| 执行顺序 | Interceptor ID | 类名 | 包含路径 | 排除路径 | Order 值 |
|----------|---------------|------|----------|----------|----------|
| 1 | INTC-001 | LoginInterceptor | /** | /login, /static/** | 1 |

## Filter 与 Interceptor 交叉关系

| URL 模式 | Filter 覆盖 | Interceptor 覆盖 | 保护层级 |
|----------|-------------|------------------|----------|
| /api/** | Spring Security (authenticated) | LoginInterceptor (session check) | 双重保护 |
| /login | Spring Security (permitAll) | LoginInterceptor excludePathPatterns | 无保护（设计如此） |

## 审计范围
- HandlerInterceptor: {count} 个
- 静态资源配置: {count} 个

## 断言结果
| 断言 | 目标 | 状态 | 证据 | 详情 | 可达性 | 调整后严重度 |
|------|------|------|------|------|--------|-------------|
| I1: 鉴权检查 | INTC-001 | FAIL | UserInterceptor.java:23 | preHandle 返回 true 无检查 | PARTIALLY_REACHABLE | MEDIUM |

## 可达性评估详情

| 漏洞ID | 原始严重度 | 可达性 | 调整后严重度 | 前置拦截组件 | 理由 |
|--------|-----------|--------|-------------|-------------|------|
| I1-INTC-001 | HIGH | PARTIALLY_REACHABLE | MEDIUM | Spring Security FilterChain | Spring Security 已要求认证，但 Interceptor 未做角色检查，已认证用户可越权 |
```

### output/phase4-api-audit.md

```markdown
# Phase 4: API 正向审计报告

## 路由映射
| 方法 | 路径 | 业务用途 | Controller | 方法 | 认证 | 风险等级 |
|------|------|----------|------------|------|------|----------|
| POST | /SqlInjection/attack8 | 员工信息查询（含机密数据） | SqlInjectionLesson8 | completed | 是 | CRITICAL |

## 端点审计详情

### POST /SqlInjection/attack8

**业务用途**: 员工信息查询接口，可查询员工薪资、信用卡等机密信息
**Controller**: org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java:43
**认证**: 是（来源: SecurityFilterChain SC2 — anyRequest().authenticated()）
**过滤**: 否（来源: Filter 层 — 无自定义 Filter 覆盖该路径）
**鉴权**: 否（来源: Interceptor 层 — UserInterceptor I1=FAIL，preHandle 始终返回 true）
**关联配置**: server.error.include-stacktrace=always (application-webgoat.properties:1)

**框架防护分析**:

| 防护层 | 覆盖组件 | 审计结果 | 可达性 | 对该端点的影响 |
|--------|----------|----------|--------|---------------|
| Filter 层 | 无自定义 Filter | N/A | - | 无自定义 Filter 覆盖该路径 |
| SecurityFilterChain | SEC-CONFIG-001 | SC1=FAIL(CSRF禁用), SC3=FAIL(NoOp), SC6=FAIL(安全头禁用) | REACHABLE | 该端点无 CSRF 保护、无安全头 |
| Interceptor 层 | UserInterceptor | I1=FAIL(无鉴权) | PARTIALLY_REACHABLE | Spring Security 已要求认证，但无角色检查 |
| 启动安全配置 | passwordEncoder | BC1=FAIL(NoOpPasswordEncoder) | - | 密码明文存储，数据库泄露即全部沦陷 |

**综合防护等级**: UNPROTECTED

**参数分析**:

| 参数 | 类型 | 业务含义 | Source 识别 | 校验方式 | 是否消毒 | Processing 链 | Sink | 结论 |
|------|------|----------|------------|----------|----------|--------------|------|------|
| name | @RequestParam String | 员工姓氏查询条件 | 用户可控 | 无 | 否 | 直接字符串拼接 | Statement.executeQuery | FAIL: SQL注入 |
| auth_tan | @RequestParam String | 员工认证令牌 | 用户可控 | 无 | 否 | 直接字符串拼接 | Statement.executeQuery | FAIL: SQL注入 |

**参数消毒分析**:

| 参数 | 消毒方式 | 消毒位置 | 消毒评估 | 理由 |
|------|----------|----------|----------|------|
| name | 无 | - | 未消毒 | 从 Source 到 Sink 无任何净化操作 |
| auth_tan | 无 | - | 未消毒 | 从 Source 到 Sink 无任何净化操作 |

**正向链路**:

Step 1: 用户输入进入方法
  位置: org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java:43
  代码: public AttackResult completed(@RequestParam String name, @RequestParam String auth_tan)
  说明: name 和 auth_tan 来自 HTTP 请求参数，用户完全可控 【Source】
  参数状态: 原始用户输入

Step 2: 参数直接传递到内部方法
  位置: org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java:44
  代码: return injectableQueryConfidentiality(name, auth_tan);
  说明: 参数未经任何校验或净化，直接传递 【无净化】
  参数状态: 原始用户输入

Step 3: 字符串拼接构建 SQL 查询
  位置: org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java:49-54
  代码: "SELECT * FROM employees WHERE last_name = '" + name + "' AND auth_tan = '" + auth_tan + "'"
  说明: 用户输入直接拼接到 SQL 语句，无 PreparedStatement 【危险】
  参数状态: 已拼接到 SQL 语句

Step 4: 执行 SQL 查询
  位置: org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java:62
  代码: ResultSet results = statement.executeQuery(query);
  说明: 拼接后的 SQL 直接执行，攻击者可注入任意 SQL 【Sink】
  参数状态: SQL 语句被执行

**完整 Sink 路径**:
  org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java:43 → org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.injectableQueryConfidentiality():44 → org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java:62
  问题: org.owasp.webgoat.lessons.sqlinjection.SqlInjectionLesson8.java 的 injectableQueryConfidentiality 方法，第 62 行，存在 SQL 注入漏洞

**业务影响**: 员工数据查询接口，攻击者可获取所有员工信息（含信用卡号、认证令牌），可进一步通过 UNION 注入获取系统任意数据

**配置文件关联**: 无关联配置

**PoC**: `name=' UNION SELECT userid, user_name, password, cookie, null, null, null FROM user_system_data --`

## 配置文件风险关联
| 配置键 | 配置值 | 关联API | 风险影响 |
|--------|--------|---------|----------|
| cors.allowed-origins | * | 所有 API | CORS 允许所有来源，加剧 CSRF 风险 |
| server.error.include-stacktrace | always | 所有 API | SQL 异常时泄露堆栈信息 |

## 启动时安全配置关联
| Bean 名称 | Bean 类型 | BC 断言结果 | 关联API | 影响说明 |
|----------|----------|------------|---------|----------|
| passwordEncoder | NoOpPasswordEncoder | BC1=FAIL | POST /register.mvc, POST /login | 密码明文存储 |
| restTemplate | RestTemplate | BC6=PASS | /WebWolf/mail/send | 无超时配置，可被 SSRF 利用 |

## 框架防护覆盖汇总
| 端点 | Filter 覆盖 | SecurityFilterChain | Interceptor 覆盖 | 综合防护等级 | 关键缺陷 |
|------|------------|--------------------|--------------------|-------------|----------|
| POST /SqlInjection/attack8 | 无 | SEC-CONFIG-001 (SC1/SC3/SC6=FAIL) | UserInterceptor (I1=FAIL) | UNPROTECTED | CSRF禁用+密码明文+无安全头 |

## 漏洞汇总
| # | 类型 | 严重度 | 端点 | 完整 Sink 路径 | PoC |
|---|------|--------|------|----------------|-----|
| 1 | SQL注入 | CRITICAL | POST /SqlInjection/attack8 | SqlInjectionLesson8.java:43 → :44 → :62 | name=' UNION SELECT ... -- |
```

### output/comprehensive-security-analysis.md

```markdown
# 综合安全分析报告

## 1. 业务安全分析

### 1.1 核心业务流程风险

| # | 业务场景 | 关联API | 风险类型 | 严重度 | 业务影响 |
|---|----------|---------|----------|--------|----------|
| 1 | 用户认证登录 | POST /login, POST /register.mvc | 密码明文存储 | CRITICAL | 数据库泄露即全部账户沦陷 |
| 2 | 员工机密查询 | POST /SqlInjection/attack8 | SQL注入 | CRITICAL | 全量员工敏感数据（含信用卡）泄露 |
| 3 | 文件上传管理 | POST /PathTraversal/profile-upload | 路径穿越 | HIGH | 服务器任意文件写入，可植入 WebShell |

### 1.2 数据资产敏感度分级

| 敏感级别 | 数据类型 | 存储位置 | 关联API | 保护措施 |
|----------|----------|----------|---------|----------|
| 极高 | 用户密码 | HSQLDB users 表 | POST /register.mvc | NoOpPasswordEncoder（无保护） |
| 高 | 员工信用卡号 | HSQLDB employees 表 | POST /SqlInjection/attack8 | 无（SQL注入可达） |
| 高 | JWT 签名密钥 | 代码硬编码 | /JWT/* | 硬编码在源码中 |
| 中 | 用户会话 Cookie | 内存 | 全局 | Spring Security 默认 |

### 1.3 业务逻辑漏洞

| # | 漏洞类型 | 端点 | 业务影响 |
|---|----------|------|----------|
| 1 | 越权访问 | PUT /IDOR/profile/{userId} | 可修改任意用户个人资料 |
| 2 | CSRF 无防护 | 所有 POST/PUT/DELETE 端点 | CSRF 禁用，所有状态变更接口可被跨站伪造 |

## 2. 技术安全分析

### 2.1 漏洞类型分布

| 漏洞类型 | 数量 | 最高严重度 | 共性模式 | 系统性风险 |
|----------|------|-----------|----------|-----------|
| SQL注入 | 10 | CRITICAL | 所有 SQL 查询均使用字符串拼接，无 PreparedStatement | 系统性缺陷 — 项目未采用参数化查询模式 |
| XXE | 3 | CRITICAL | XMLInputFactory 安全属性由布尔开关控制，所有调用方传 false | 系统性缺陷 — 安全保护可被调用方关闭 |
| 反序列化 | 2 | CRITICAL | ObjectInputStream + XStream 均无类型白名单 | 系统性缺陷 — 未建立反序列化安全框架 |
| 路径穿越 | 2 | HIGH | 文件名/路径直接使用用户输入，无规范化 | 系统性缺陷 — 缺少统一的路径安全工具类 |
| SSRF | 2 | HIGH | URL 直接使用用户输入，无白名单 | 系统性缺陷 — 缺少 URL 校验工具类 |
| 弱密码学 | 2 | MEDIUM | 使用 MD5 + java.util.Random | 局部问题 |

### 2.2 技术债务评估

| 技术债务 | 影响范围 | 修复成本 | 优先级 |
|----------|----------|----------|--------|
| 全局未使用 PreparedStatement | 所有 SQL 操作 | 高（需重构所有 DAO 层） | P0 |
| XStream 1.4.5 已知 CVE | XML 处理模块 | 中（升级 + 配置安全框架） | P0 |
| 无统一输入校验框架 | 所有 API 端点 | 高（需引入 Bean Validation） | P1 |

## 3. 配置安全分析

### 3.1 应用配置风险

| # | 配置类别 | 配置项 | 当前值 | 风险等级 | 建议值 | 影响范围 |
|---|----------|--------|--------|----------|--------|----------|
| 1 | SSL | server.ssl.enabled | false | HIGH | true | 所有通信明文传输 |
| 2 | 错误处理 | server.error.include-stacktrace | always | HIGH | never | 堆栈信息泄露 |
| 3 | Actuator | management.endpoints.web.exposure.include | env,health,configprops | HIGH | health | 敏感配置端点暴露 |
| 4 | 密钥管理 | server.ssl.key-store-password | password | HIGH | 环境变量注入 | 密钥库密码硬编码 |

### 3.2 SecurityFilterChain 配置风险

| # | 配置项 | 当前值 | 风险等级 | 建议值 | 影响范围 |
|---|--------|--------|----------|--------|----------|
| 1 | CSRF | disabled | CRITICAL | enabled | 所有状态变更 API |
| 2 | HTTP Headers | disabled | HIGH | enabled (默认值) | 缺少 X-Frame-Options、CSP 等 |
| 3 | PasswordEncoder | NoOpPasswordEncoder | CRITICAL | BCryptPasswordEncoder | 所有用户密码 |
| 4 | permitAll 路径 | /actuator/** | HIGH | 移除 /actuator/** | Actuator 端点无认证 |

### 3.3 启动时安全配置风险

| # | Bean/初始化 | 类型 | 风险描述 | 风险等级 |
|---|------------|------|----------|----------|
| 1 | passwordEncoder | @Bean | NoOpPasswordEncoder 明文存储密码 | CRITICAL |
| 2 | RestTemplate | @Bean | 无超时配置，可被 SSRF 利用导致线程阻塞 | MEDIUM |

### 3.4 环境差异风险

| 配置项 | dev 值 | prod 预期值 | 差异风险 |
|--------|--------|------------|----------|
| server.ssl.enabled | false | true（需确认） | 若 prod 未覆盖则明文传输 |
| OAuth2 client-secret | dummy | 真实密钥（需确认） | 若 prod 未覆盖则 OAuth 不可用 |

## 4. 交叉关联分析

### 4.1 配置 + 技术 复合风险

| # | 复合风险描述 | 配置缺陷 | 技术漏洞 | 综合严重度 |
|---|-------------|----------|----------|-----------|
| 1 | CSRF 全面可达 | CSRF disabled (SC1) | 所有 POST/PUT/DELETE 端点无 Token 校验 | CRITICAL |
| 2 | Actuator 信息泄露辅助攻击 | /actuator/** permitAll (SC2) | env/configprops 暴露数据库连接串 | HIGH |

### 4.2 业务 + 技术 复合风险

| # | 复合风险描述 | 业务场景 | 技术漏洞 | 综合严重度 |
|---|-------------|----------|----------|-----------|
| 1 | 全量用户数据泄露 | 用户认证系统 | SQL注入 + 密码明文存储 | CRITICAL |
| 2 | 服务器完全接管 | 文件上传功能 | 路径穿越 + 反序列化 RCE | CRITICAL |

### 4.3 三维复合风险（业务 + 技术 + 配置）

| # | 复合风险描述 | 攻击链 | 综合严重度 |
|---|-------------|--------|-----------|
| 1 | 完全接管应用 | CSRF(配置) → 管理员操作(业务) → SQL注入(技术) → 数据库完全控制 | CRITICAL |
| 2 | 认证体系崩溃 | 密码明文(配置) → 数据库泄露(技术) → 所有用户账户沦陷(业务) | CRITICAL |
| 3 | 服务器沦陷 | 文件上传(业务) + 路径穿越(技术) + 无SSL(配置) → 中间人+WebShell | CRITICAL |

## 5. 攻击面总览

| 攻击面类型 | 入口点数量 | 最高风险 | 关键发现 |
|-----------|-----------|----------|----------|
| 外部攻击面（未认证） | {count} | CRITICAL | /actuator/** 无需认证，/registration 和 /register.mvc 无需认证 |
| 内部攻击面（认证后） | {count} | CRITICAL | 认证后几乎所有 API 存在 SQL 注入 / XXE / 反序列化等漏洞 |
| 配置攻击面 | {count} | CRITICAL | CSRF 禁用、密码明文、安全头禁用、Actuator 暴露 |
| 供应链攻击面 | {count} | HIGH | XStream 1.4.5 (CVE-2013-7285)、commons-collections 3.2.1 (CVE-2015-6420) |

## 6. 修复优先级路线图

### P0 — 立即修复（CRITICAL）
1. 启用 CSRF 保护
2. 替换 NoOpPasswordEncoder 为 BCryptPasswordEncoder
3. 全面使用 PreparedStatement 参数化查询
4. 升级 XStream 并启用安全框架
5. XMLInputFactory 强制禁用外部实体

### P1 — 短期修复（HIGH）
1. 启用 HTTP 安全头
2. 限制 Actuator 端点访问（添加认证或仅暴露 health）
3. 启用 SSL
4. 文件上传路径规范化 + UUID 重命名
5. URL 白名单校验防 SSRF

### P2 — 中期修复（MEDIUM）
1. 引入 Bean Validation 统一输入校验
2. 替换 MD5 为 SHA-256
3. 替换 java.util.Random 为 SecureRandom
4. 移除硬编码密钥/密码

### P3 — 长期改进（LOW/INFO）
1. 建立统一的安全工具类库
2. 引入 SAST/DAST 自动化扫描
3. 建立安全编码规范
```
