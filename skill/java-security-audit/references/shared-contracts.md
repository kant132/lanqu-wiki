# 共享契约

所有 Phase Skill 必须遵守本契约。

## 断言结果状态

| 状态 | 含义 | 使用场景 |
|------|------|----------|
| PASS | 安全检查通过 | 代码实现正确，无安全风险 |
| FAIL | 安全检查失败 | 确认存在安全缺陷，需提供代码证据和 PoC |
| FALSE_POSITIVE | 表面风险但实际安全 | 存在补偿控制或框架层面已防护，需明确说明理由 |
| N/A | 不适用 | 该检查项与当前组件无关 |

### Phase 断言索引

各 Phase 的断言定义详见对应子 Skill。调度Agent必须验证所有强制断言已评估:

| Phase | 断言ID范围 | 子Skill |
|-------|-----------|---------|
| Phase 1 | C1-C5 | java-recon |
| Phase 2 | P1-P7 | java-filter-audit |
| Phase 3 | 详见子Skill | java-interceptor-audit |
| Phase 4 | L1.x | java-lsp-trace |
| Phase 5 | 详见子Skill | java-api-risk |

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

### Backtrack-Request（Phase 5 → 调度Agent → Phase 4）

```json
{
  "type": "backtrack",
  "target_method": "com.example.FileService.download",
  "target_file": "src/main/java/com/example/FileService.java",
  "target_line": 42,
  "trace_depth": 3,
  "reason": "发现文件操作Sink，需追踪参数来源"
}
```

### Lateral-Expand-Request（Phase 5 → 调度Agent → Phase 5）

```json
{
  "type": "lateral_expand",
  "new_endpoints": [
    {
      "path": "GET /api/v1/files/{fileId}",
      "controller": "FileController",
      "reason": "从 download 方法追踪发现关联端点"
    }
  ]
}
```

## 熔断传播规则

| 触发源 | 熔断标记 | 下游影响 |
|--------|----------|----------|
| Phase 2 FAIL | `filter_bypassed: true` | Phase 5 `全局过滤因子` 强制取 5 |
| Phase 3 FAIL | `interceptor_bypassed: true` | Phase 5 `鉴权因子` 强制取 5 |
| Phase 4 L1.1 触发 | `lsp_unresolved: true` | Phase 5 `confidence: LOW` |
| Phase 5 一票否决 | `priority: LOW` | 不触发 LSP 深度追踪 |

## 数据结构定义

### merge() 函数

```typescript
type CircuitBreaker = {
  type: "filter_bypassed" | "interceptor_bypassed" | "lsp_unresolved";
  target: string;
  severity: "WARN" | "ERROR" | "CRITICAL";
  affected_paths?: string[];
};

function merge(a: CircuitBreaker[], b: CircuitBreaker[]): CircuitBreaker[] {
  // 1. Union 并集，按 (type + target) 去重
  const map = new Map<string, CircuitBreaker>();
  for (const item of [...a, ...b]) {
    const key = `${item.type}:${item.target}`;
    if (!map.has(key)) {
      map.set(key, item);
    } else {
      // 2. 冲突解决：同 type+target，高 severity 覆盖低 severity
      const existing = map.get(key)!;
      if (severityRank(item.severity) > severityRank(existing.severity)) {
        map.set(key, item);
      }
    }
  }
  return Array.from(map.values());
}

function severityRank(s: "WARN" | "ERROR" | "CRITICAL"): number {
  return { WARN: 1, ERROR: 2, CRITICAL: 3 }[s];
}
```

### Phase 5 输入协议

```json
{
  "asset_inventory": { /* Asset-Inventory JSON */ },
  "circuit_breakers": { /* merged_circuit_breakers */ },
  "overridden_factors": {
    "auth_factor": null,           // null=自行评估 | 5=熔断强制覆盖(interceptor_bypassed)
    "global_filter_factor": null,  // null=自行评估 | 5=熔断强制覆盖(filter_bypassed)
    "param_validation_factor": null,
    "high_risk_param_factor": null,
    "business_significance_factor": null
  },
  "phase4_results": { /* Phase-Result JSON，P4跳过时为 status: "skipped_degraded" */ },
  "backtrack_results": [ /* Phase-Result JSON 数组，回溯历史，用于扩展信任链分析 */ ],
  "current_backtrack_index": 0,   // 当前回溯序号（0=主流程，1-N=第N次回溯）
  "input_type": "scheduled",      // "scheduled" | "backtrack" | "lateral_expand"
  "lateral_expand_endpoints": [], // 横向扩展专用：新增待审计端点列表
  "lateral_expand_index": 0,      // 横向扩展序号（0=主流程，1-N=第N次横向扩展）
  "max_backtrack": 5,
  "max_lateral_expand": 3,
  "degraded_mode": false          // 降级模式标识，影响风险阈值
}
```

### Phase 5 输入协议 - 降级模式变体

当 `degraded_mode = true` 时，输入协议字段变化：

```json
{
  "max_backtrack": 2,             // 减少无效追踪
  "threshold": "MEDIUM",          // 降为 MEDIUM 及以上（正常为 HIGH/CRITICAL）
  "phase4_results": {
    "phase": "Phase 4",
    "assertions": [],
    "circuit_breakers": [],
    "status": "skipped_degraded"
  }
}
```

### Phase 5 输出协议

```json
{
  "status": "complete",     // "complete" | "partial" | "max_iteration_reached"
  "findings": [            // 漏洞发现列表
    {
      "id": "SEC-XXX-001",
      "severity": "CRITICAL",
      "endpoint": "GET /api/v2/files/{fileId}",
      "source": "污点追踪",
      "poc": "..."
    }
  ],
  "backtrack_requests": [  // 回溯请求列表
    {
      "type": "backtrack",
      "target_method": "com.example.FileService.download",
      "target_file": "src/main/java/com/example/FileService.java",
      "target_line": 42,
      "trace_depth": 3,
      "reason": "发现文件操作Sink，需追踪参数来源"
    }
  ],
  "lateral_expand_requests": [],  // 横向扩展请求列表
  "hasBacktrackRequest": false,   // 辅助字段，供调度Agent判断
  "hasLateralExpandRequest": false
}
```

## 快速失败错误码

| 错误码 | 含义 | 触发条件 |
|--------|------|----------|
| ERR-NO-BUILD | 无构建文件 | pom.xml 和 build.gradle 均不存在 |
| ERR-NO-ENGINE | 无路由引擎 | 未检测到任何 Web 框架 |
| ERR-EMPTY-INVENTORY | 资产台账为空 | Phase 1 未提取到任何组件 |
| ERR-LSP-TIMEOUT | LSP 超时 | LSP 操作超过 30 秒 |
| ERR-LSP-DEPTH | LSP 深度熔断 | 跳转超过 MAX_LSP_DEPTH(3) 层 |
| ERR-BACKTRACK-LIMIT | 回溯次数耗尽 | Phase 5 回溯超过 5 次 |
