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

## 1. 审计元数据

| 项目 | 内容 |
|------|------|
| 构建文件 | pom.xml / build.gradle |
| 路由引擎 | {engines} |
| 审计范围 | 框架分析 + API分析 |

## 2. 框架分析结果（Part 1）

### 2.1 资产统计

| 类型 | 数量 |
|------|------|
| 路由引擎 | {engines_count} |
| 自定义 Filter | {filters_count} |
| SecurityFilterChain | {security_configs_count} |
| Interceptor | {interceptors_count} |

### 2.2 Filter/SecurityFilterChain 审计

| 断言 | 目标 | 状态 | 证据 |
|------|------|------|------|
| P1 | {target} | PASS/FAIL | {file:line} |

### 2.3 Interceptor 审计

| 断言 | 目标 | 状态 | 证据 |
|------|------|------|------|
| I1 | {target} | PASS/FAIL | {file:line} |

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

## 4. 修复建议

1. ...
2. ...

## 5. 资产守恒验证

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
# Phase 2: Filter/SecurityFilterChain 审计报告

## 审计范围
- 自定义 Filter: {count} 个
- SecurityFilterChain: {count} 个
- web.xml Filter: {count} 个

## 断言结果
| 断言 | 目标 | 状态 | 证据 | 详情 |
|------|------|------|------|------|
| P1: CSRF 配置 | SEC-CONFIG-001 | FAIL | WebSecurityConfig.java:61 | csrf.disable() |

## 熔断记录
| 类型 | 目标 | 严重度 | 影响范围 |
|------|------|--------|----------|
| filter_bypassed | FILTER-001 | ERROR | /api/* |
```

### output/phase3-interceptor-audit.md

```markdown
# Phase 3: Interceptor 审计报告

## 审计范围
- HandlerInterceptor: {count} 个
- 静态资源配置: {count} 个

## 断言结果
| 断言 | 目标 | 状态 | 证据 | 详情 |
|------|------|------|------|------|
| I1: 鉴权检查 | INTC-001 | FAIL | UserInterceptor.java:23 | preHandle 返回 true 无检查 |
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
**认证**: 是（Spring Security）
**过滤**: 否（无自定义 Filter 覆盖）
**鉴权**: 否（Interceptor 无功能）
**关联配置**: 无关联配置

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

## 漏洞汇总
| # | 类型 | 严重度 | 端点 | 完整 Sink 路径 | PoC |
|---|------|--------|------|----------------|-----|
| 1 | SQL注入 | CRITICAL | POST /SqlInjection/attack8 | SqlInjectionLesson8.java:43 → :44 → :62 | name=' UNION SELECT ... -- |
```
