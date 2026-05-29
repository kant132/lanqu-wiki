# 共享契约

所有 Phase Skill 必须遵守本契约。

## 断言结果状态

| 状态 | 含义 | 使用场景 |
|------|------|----------|
| PASS | 安全检查通过 | 代码实现正确，无安全风险 |
| FAIL | 安全检查失败 | 确认存在安全缺陷，需提供代码证据和 PoC |
| FALSE_POSITIVE | 表面风险但实际安全 | 存在补偿控制或框架层面已防护，需明确说明理由 |
| N/A | 不适用 | 该检查项与当前组件无关 |

## 漏洞可达性等级

| 等级 | 含义 | 严重度调整 |
|------|------|-----------|
| REACHABLE | 漏洞可被实际触发，无前置拦截或后置补偿 | 保持原严重度 |
| PARTIALLY_REACHABLE | 部分场景可达，存在条件限制（如需认证、特定角色） | 严重度降一级 |
| UNREACHABLE | 被前置 Filter/Interceptor 拦截或后置补偿，实际不可触发 | 降为 INFO（提示级别） |

## 严重度等级

| 等级 | 含义 | 使用场景 |
|------|------|----------|
| CRITICAL | 严重 | 可直接 RCE、全量数据泄露、认证绕过 |
| HIGH | 高危 | 敏感数据泄露、权限提升、SSRF |
| MEDIUM | 中危 | 有限信息泄露、非敏感操作绕过 |
| LOW | 低危 | 代码质量问题、配置不当但影响有限 |
| INFO | 提示 | 代码质量提示、被其他防护层覆盖的潜在风险 |

## Phase 断言索引

各 Phase 的断言定义详见对应子 Skill。调度Agent必须验证所有强制断言已评估:

| Phase | 断言ID范围 | 子Skill |
|-------|-----------|---------|
| Phase 1 | C1-C7 | java-recon |
| Phase 2 第一层 | P1-P7 | java-filter-audit (Filter 类代码) |
| Phase 2 第二层 | FC1-FC6 | java-filter-audit (Filter 注册配置) |
| Phase 2 第三层 | SC1-SC10 | java-filter-audit (SecurityFilterChain 配置) |
| Phase 2b | BC1-BC8 | 启动时安全配置审计 |
| Phase 3 | I1-I7, S1-S4 | java-interceptor-audit |
| Phase 4 | 详见子Skill | java-api-risk |

## 跨Phase数据协议

### Asset-Inventory（Phase 1 输出）

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
  "security_configs": [
    {
      "id": "SEC-CONFIG-001",
      "class": "com.example.WebSecurityConfig",
      "csrf_disabled": true,
      "permit_all_paths": ["/favicon.ico", "/css/**", "/actuator/**"],
      "password_encoder": "NoOpPasswordEncoder"
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
  "config_sources": ["WebMvcConfig.java", "web.xml"],
  "filter_registrations": [
    {
      "id": "FR-001",
      "filter_id": "FILTER-001",
      "registration_type": "FilterRegistrationBean",
      "source": "WebConfig.java:45",
      "url_patterns": ["/api/*"],
      "order": 1,
      "dispatcher_types": ["REQUEST", "FORWARD"],
      "init_parameters": {},
      "conditional": null
    }
  ],
  "startup_security_beans": [
    {
      "id": "SB-001",
      "bean_name": "passwordEncoder",
      "bean_type": "PasswordEncoder",
      "source": "WebSecurityConfig.java:87",
      "security_relevance": "HIGH",
      "category": "authentication"
    }
  ],
  "config_analysis": {
    "files": [
      {
        "path": "src/main/resources/application.yml",
        "profiles": ["default", "dev", "prod"]
      }
    ],
    "security_config": [
      {
        "key": "security.jwt.secret",
        "value": "[REDACTED]",
        "file": "application.yml",
        "line": 45,
        "risk": "HIGH",
        "note": "JWT 密钥硬编码"
      }
    ],
    "datasource_config": [],
    "upload_config": [],
    "actuator_config": [],
    "cors_config": [],
    "serialization_config": [],
    "custom_business_config": []
  }
}
```

### Phase-Result（Phase 2/3/4 输出）

```json
{
  "phase": "Phase 2",
  "assertions": [
    {
      "id": "P1",
      "target": "FILTER-001",
      "status": "FAIL",
      "evidence": "AuthFilter.java:45",
      "detail": "使用 getRequestURI() 但未 normalize",
      "original_severity": "HIGH",
      "reachability": "UNREACHABLE",
      "adjusted_severity": "INFO",
      "reachability_reason": "被前置 Spring Security FilterChain 拦截，未认证请求无法到达该 Filter"
    }
  ],
  "execution_order": {
    "chain": ["AuthFilter(order=1)", "RateLimitFilter(order=2)", "PathValidationFilter(order=3)"],
    "visualization": "Request → AuthFilter → RateLimitFilter → PathValidationFilter → Servlet"
  },
  "circuit_breakers": [
    {
      "type": "filter_bypassed",
      "target": "FILTER-001",
      "severity": "ERROR",
      "affected_paths": ["/api/*"],
      "reachability": "UNREACHABLE"
    }
  ]
}
```

## 熔断传播规则

| 触发源 | 熔断标记 | 下游影响 |
|--------|----------|----------|
| Phase 2 FAIL (REACHABLE) | `filter_bypassed: true` | Phase 4 对应端点的全局过滤因子强制取 5 |
| Phase 2 FAIL (PARTIALLY_REACHABLE) | `filter_bypassed: true` | Phase 4 对应端点的全局过滤因子强制取 3 |
| Phase 2 FAIL (UNREACHABLE) | `filter_bypassed: true` (INFO) | 不传播到 Phase 4，仅记录为代码质量提示 |
| Phase 3 FAIL (REACHABLE) | `interceptor_bypassed: true` | Phase 4 对应端点的鉴权因子强制取 5 |
| Phase 3 FAIL (PARTIALLY_REACHABLE) | `interceptor_bypassed: true` | Phase 4 对应端点的鉴权因子强制取 3 |
| Phase 3 FAIL (UNREACHABLE) | `interceptor_bypassed: true` (INFO) | 不传播到 Phase 4，仅记录为代码质量提示 |
| Phase 2/3 均无 FAIL | 无熔断标记 | Phase 4 自行评估各因子 |

## 快速失败错误码

| 错误码 | 含义 | 触发条件 |
|--------|------|----------|
| ERR-NO-BUILD | 无构建文件 | pom.xml 和 build.gradle 均不存在 |
| ERR-NO-ENGINE | 无路由引擎 | 未检测到任何 Web 框架 |
| ERR-EMPTY-INVENTORY | 资产台账为空 | Phase 1 未提取到任何组件 |
