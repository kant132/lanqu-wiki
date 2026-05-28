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
| 方法 | 路径 | Controller | 方法 | 认证 | 风险等级 |
|------|------|------------|------|------|----------|
| POST | /SqlInjection/attack8 | SqlInjectionLesson8 | completed | 是 | CRITICAL |

## 端点审计详情

### POST /SqlInjection/attack8

**Controller**: SqlInjectionLesson8.java
**认证**: 是（Spring Security）
**过滤**: 否（无自定义 Filter 覆盖）
**鉴权**: 否（Interceptor 无功能）

**参数分析**:

| 参数 | 类型 | Source 识别 | Processing 链 | Sink | 结论 |
|------|------|------------|--------------|------|------|
| name | @RequestParam | 用户可控 | 直接字符串拼接 | Statement.executeQuery | FAIL: SQL注入 |

**正向链路**:
```
Source: @RequestParam name (用户可控输入)
  → Processing: "SELECT * FROM employees WHERE last_name = '" + name + "'" (字符串拼接)
  → Sink: statement.executeQuery(query) (SQL执行)
  → 结论: SQL注入漏洞
```

**业务影响**: 员工数据查询接口，攻击者可获取所有员工信息

**PoC**: `name=' UNION SELECT ... --`

## 漏洞汇总
| # | 类型 | 严重度 | 端点 | 正向链路 |
|---|------|--------|------|----------|
| 1 | SQL注入 | CRITICAL | POST /SqlInjection/attack8 | name → 拼接 → executeQuery |
```
