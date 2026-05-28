# 最终报告输出模板

## [FINAL_SUMMARY_REPORT]

```markdown
[FINAL_SUMMARY_REPORT]

# 0. 执行摘要 (Executive Summary)
executive_summary:
  overall_risk_level: "CRITICAL / HIGH / MEDIUM / LOW"
  total_vulnerabilities: INT
  critical_count: INT
  high_count: INT
  top_3_fix_priorities:
    - vuln_id: "SEC-CHAIN-XXX"
      title: "漏洞标题"
      reason: "为什么必须优先修复"
  one_line_verdict: "一句话总结审计结论，面向管理层"

# 1. 审计元数据 (Audit Metadata)
meta:
  scan_time: "2026-05-27T11:00:00Z"
  engine_version: "SAST-Engine-V5.2-LSP"
  target_project_hash: "SHA256_HASH_OF_PROJECT"
  verdict: "FAILED_GATE" # [PASSED_GATE / FAILED_GATE] 存在重危缺陷则为 FAILED

# 2. 态势统计面板 (Security Metric Dashboard)
metrics:
  total_assets_discovered: INT     # Phase 1 发现的资产总数
  total_assets_audited: INT        # Phase 2/3 实际完成审计的资产数
  asset_conservation_valid: true    # total_assets_discovered >= total_assets_audited 且缺失资产已记录
  rest_endpoints_mapped: INT       # Phase 5 盘点出的后端路由端点数
  parameter_taint_chains_traced: INT # Phase 4 执行 LSP 追踪的污点链总数
  backtrack_count: INT             # 实际回溯次数（max 5）
  lateral_expand_count: INT        # 实际横向扩展次数（max 3）
  vulnerability_counts:
    critical: INT                  # 成功闭环的穿透性漏洞
    high: INT                      # 中间件单纯绕过/信任链污染
    medium: INT                    # 配置层高风险缺陷/白名单过宽
    low: INT                       # 编码规范/大小写敏感隐患

# 3. 闭环威胁链路矩阵 (Closed Vulnerability Chains)
vulnerability_chains:
  - vuln_id: "SEC-CHAIN-001"
    title: "越权穿透与后端路由参数注入复合高危漏洞"
    severity: "CRITICAL"
    vector:
      step_1_bypass:
        component_id: "F001"
        type: "Filter_Path_Bypass"
        sink_triggered: ".endsWith()"
        payload_example: "/api/v2/privilege/dump;.js"
      step_2_pollution:
        context_type: "HttpServletRequest_Attribute"
        key: "X-Gate-Pass"
        polluted_by: "GatewaySecurityFilter"
        trusted_by: "RoutingAuthInterceptor"
      step_3_routing:
        engine: "Spring MVC / JAX-RS / Native Servlet"
        controller_class: "com.target.action.AdminController"
        matched_path: "/api/v2/privilege/dump"
      step_4_taint_sink:
        parameter_name: "fileId"
        binding_annotation: "@PathVariable"
        lsp_resolved_sink: "java.io.FileInputStream.<init>"
        taint_status: "UNSANITIZED"
    remediation:
      priority: "P0"                # P0=立即修复 P1=本迭代修复 P2=下迭代修复
      immediate_action: "在 Filter 中引入路径规范化算子并采用全锚定正则匹配，清除分号矩阵变量"
      defense_in_depth: "在核心 Controller 方法上强制追加局部鉴权注解（如 @PreAuthorize）进行二线纵深防御"
      code_diff_example: |
        # Filter.java:45
        - String requestUri = request.getRequestURI();
        + String requestUri = request.getRequestURI();
        + requestUri = decodeAndNormalize(requestUri);
        + if (isStaticResource(requestUri)) {
             chain.doFilter(request, response);
             return;
        + }
      architectural_fix: "强制所有 @Controller 继承 BaseSecuredController，在基类 preHandle 中实现二次鉴权"

# 4. 纵深防御缺失评估 (Defense-in-Depth Deficit)
defense_deficit_analysis:
  naked_endpoints_count: INT       # 没有任何方法级权限注解兜底的核心公开端点数
  framework_mismatch_risks:
    - risk_type: "Trailing Slash / Matrix Parameter Resolution Discrepancy"
      description: "中间件与路由层存在分号截断或斜杠容错差异"

# 5. 自动化契约审计闭环断言 (Verification Guardrail)
guardrail_assertions:
  asset_count_conserved: true       # Phase1总量 >= Phase2+3审计总量，缺失资产已记录
  lsp_no_blackbox_guessing: true    # 自定义鉴权方法已 100% 符号展开
  hybrid_route_aligned: true        # 已根据实际组件动态提取路由
  param_taint_trace_closed: true    # 所有暴露端点入参均完成到 Sink 的流向断言
  backtrack_limit_respected: true   # backtrack_count <= 5
  lateral_expand_limit_respected: true # lateral_expand_count <= 3
```

## 字段说明

### executive_summary

| 字段 | 类型 | 说明 |
|------|------|------|
| `overall_risk_level` | String | 整体风险等级：CRITICAL/HIGH/MEDIUM/LOW |
| `total_vulnerabilities` | INT | 漏洞总数 |
| `critical_count` | INT | CRITICAL 级别漏洞数 |
| `high_count` | INT | HIGH 级别漏洞数 |
| `top_3_fix_priorities` | Array | 最优先修复的 Top 3 漏洞 |
| `one_line_verdict` | String | 面向管理层的一句话结论 |

### meta

| 字段 | 类型 | 说明 |
|------|------|------|
| `scan_time` | TIMESTAMP | 扫描时间 |
| `engine_version` | String | 引擎版本 |
| `target_project_hash` | String | 项目哈希值 |
| `verdict` | String | PASSED_GATE / FAILED_GATE |

### metrics

| 字段 | 类型 | 说明 |
|------|------|------|
| `total_assets_discovered` | INT | 发现的资产总数 |
| `total_assets_audited` | INT | 完成审计的资产数 |
| `rest_endpoints_mapped` | INT | 路由端点总数 |
| `parameter_taint_chains_traced` | INT | LSP追踪链总数 |
| `vulnerability_counts` | Object | 漏洞统计 |

### vulnerability_chains

| 字段 | 类型 | 说明 |
|------|------|------|
| `vuln_id` | String | 漏洞ID |
| `title` | String | 漏洞标题 |
| `severity` | String | CRITICAL/HIGH/MEDIUM/LOW |
| `vector` | Object | 攻击向量详情 |
| `remediation` | Object | 修复建议 |
| `remediation.priority` | String | 修复优先级：P0=立即修复 / P1=本迭代 / P2=下迭代 |

### guardrail_assertions

| 字段 | 类型 | 说明 |
|------|------|------|
| `asset_count_conserved` | Boolean | 资产总量守恒（P1 ≥ P2+3，缺失资产已记录） |
| `lsp_no_blackbox_guessing` | Boolean | LSP符号展开验证 |
| `hybrid_route_aligned` | Boolean | 路由提取验证 |
| `param_taint_trace_closed` | Boolean | 追踪链路闭合验证 |

## 示例

```markdown
[FINAL_SUMMARY_REPORT]

# 0. 执行摘要 (Executive Summary)
executive_summary:
  overall_risk_level: "CRITICAL"
  total_vulnerabilities: 10
  critical_count: 2
  high_count: 3
  top_3_fix_priorities:
    - vuln_id: "SEC-CHAIN-001"
      title: "越权穿透与后端路由参数注入复合高危漏洞"
      reason: "攻击者可无认证直接读取服务器任意文件"
    - vuln_id: "SEC-CHAIN-002"
      title: "反序列化远程代码执行"
      reason: "Fastjson 未禁用 autoType，可远程执行任意命令"
    - vuln_id: "SEC-SINK-001"
      title: "SQL 注入 - MyBatis ${} 拼接"
      reason: "用户输入直接拼接到 SQL 语句，可拖库"
  one_line_verdict: "项目存在 2 个 CRITICAL 级别漏洞，攻击者可无认证远程读取任意文件和执行命令，建议立即修复"

# 1. 审计元数据 (Audit Metadata)
meta:
  scan_time: "2026-05-28T10:30:00Z"
  engine_version: "SAST-Engine-V5.2-LSP"
  target_project_hash: "a3f2b1c4d5e6..."
  verdict: "FAILED_GATE"

# 2. 态势统计面板 (Security Metric Dashboard)
metrics:
  total_assets_discovered: 8
  total_assets_audited: 8
  asset_conservation_valid: true
  rest_endpoints_mapped: 24
  parameter_taint_chains_traced: 12
  backtrack_count: 2
  lateral_expand_count: 1
  vulnerability_counts:
    critical: 2
    high: 3
    medium: 4
    low: 1

# 3. 闭环威胁链路矩阵 (Closed Vulnerability Chains)
vulnerability_chains:
  - vuln_id: "SEC-CHAIN-001"
    title: "越权穿透与后端路由参数注入复合高危漏洞"
    severity: "CRITICAL"
    vector:
      step_1_bypass:
        component_id: "F001"
        type: "Filter_Path_Bypass"
        sink_triggered: ".endsWith()"
        payload_example: "/api/v2/privilege/dump;.js"
      step_2_pollution:
        context_type: "HttpServletRequest_Attribute"
        key: "X-Gate-Pass"
        polluted_by: "GatewaySecurityFilter"
        trusted_by: "RoutingAuthInterceptor"
      step_3_routing:
        engine: "Spring MVC"
        controller_class: "com.target.action.AdminController"
        matched_path: "/api/v2/privilege/dump"
      step_4_taint_sink:
        parameter_name: "fileId"
        binding_annotation: "@PathVariable"
        lsp_resolved_sink: "java.io.FileInputStream.<init>"
        taint_status: "UNSANITIZED"
    remediation:
      priority: "P0"
      immediate_action: "在 Filter 中引入路径规范化算子并采用全锚定正则匹配"
      defense_in_depth: "在核心 Controller 方法上强制追加局部鉴权注解"
      code_diff_example: |
        # Filter.java:45
        - String requestUri = request.getRequestURI();
        + String requestUri = decodeAndNormalize(request.getRequestURI());
      architectural_fix: "强制所有 @Controller 继承 BaseSecuredController"

# 4. 纵深防御缺失评估 (Defense-in-Depth Deficit)
defense_deficit_analysis:
  naked_endpoints_count: 5
  framework_mismatch_risks:
    - risk_type: "Trailing Slash / Matrix Parameter Resolution Discrepancy"
      description: "中间件与路由层存在分号截断或斜杠容错差异"

# 5. 自动化契约审计闭环断言 (Verification Guardrail)
guardrail_assertions:
  asset_count_conserved: true
  lsp_no_blackbox_guessing: true
  hybrid_route_aligned: true
  param_taint_trace_closed: true
  backtrack_limit_respected: true
  lateral_expand_limit_respected: true
```