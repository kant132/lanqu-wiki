# 共享契约

所有 Phase Skill 必须遵守本契约。

## 断言结果状态

| 状态 | 含义 | 使用场景 |
|------|------|----------|
| PASS | 安全检查通过 | 代码实现正确，无安全风险 |
| FAIL | 安全检查失败 | 确认存在安全缺陷，需提供代码证据和 PoC |
| FALSE_POSITIVE | 表面风险但实际安全 | 存在补偿控制或框架层面已防护，需明确说明理由 |
| N/A | 不适用 | 该检查项与当前组件无关 |

## Phase 断言索引

各 Phase 的断言定义详见对应子 Skill。调度Agent必须验证所有强制断言已评估:

| Phase | 断言ID范围 | 子Skill |
|-------|-----------|---------|
| Phase 1 | C1-C5 | java-recon |
| Phase 2 | P1-P7 | java-filter-audit |
| Phase 3 | 详见子Skill | java-interceptor-audit |
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
  "config_sources": ["WebMvcConfig.java", "web.xml"]
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
      "detail": "使用 getRequestURI() 但未 normalize"
    }
  ],
  "circuit_breakers": [
    {
      "type": "filter_bypassed",
      "target": "FILTER-001",
      "severity": "ERROR",
      "affected_paths": ["/api/*"]
    }
  ]
}
```

## 熔断传播规则

| 触发源 | 熔断标记 | 下游影响 |
|--------|----------|----------|
| Phase 2 FAIL | `filter_bypassed: true` | Phase 4 对应端点的全局过滤因子强制取 5 |
| Phase 3 FAIL | `interceptor_bypassed: true` | Phase 4 对应端点的鉴权因子强制取 5 |
| Phase 2/3 均无 FAIL | 无熔断标记 | Phase 4 自行评估各因子 |

## 快速失败错误码

| 错误码 | 含义 | 触发条件 |
|--------|------|----------|
| ERR-NO-BUILD | 无构建文件 | pom.xml 和 build.gradle 均不存在 |
| ERR-NO-ENGINE | 无路由引擎 | 未检测到任何 Web 框架 |
| ERR-EMPTY-INVENTORY | 资产台账为空 | Phase 1 未提取到任何组件 |
