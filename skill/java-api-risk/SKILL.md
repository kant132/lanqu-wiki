---
name: java-api-risk
description: Java API 路由风险审计与动态决策引擎。当需要提取 API 路由、计算风险评分、根据代码逻辑动态调整审计方向时加载。Use when extracting API routes, calculating risk scores, performing dynamic code-driven security audit, or when Phase 5 backtrack/lateral expansion is needed.
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Phase 5: 异构 API 路由解析与参数污点深度审计

## 输入

- Asset-Inventory JSON（来自 Phase 1）
- 熔断状态（来自 Phase 2/3/4）
- 回溯请求上下文（可选，来自调度Agent）

## 输出

- Audit-Context.json（符合 `references/phase5-audit-context-schema.md`）
- 动态审计报告

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| MAX_BACKTRACK | 5 | 最大回溯次数 |
| PARALLEL_BRANCHES | true | 是否允许分支并行审计 |
| EXTENSION_RULES | null | 用户自定义决策规则文件路径 |

## 门禁断言（R1-R5）

| 断言 | 检查项 | 说明 |
|------|--------|------|
| R1 | API异构路由全量输出 | 根据 Phase 1 感知的引擎类型，全量输出后端真实的 API 路由资产清单 |
| R2 | 路由参数全识别 | 提取目标端点方法绑定的所有外部输入参数 |
| R3 | 顺流第一道防线 | 提取声明式校验（JSR-303）、编程式校验、WAF/前置校验感知 |
| R4 | 局部鉴权兜底 | 断言检查该端点类/方法上是否具备局部鉴权注解 |
| R5 | LSP风险暴露权重计算 | 运行五维因子算法，生成 Audit-Context.json |

## 执行流程

### Step 1: 路由提取 + 风险评分

> 详见 [`references/phase5-route-extraction.md`](references/phase5-route-extraction.md)
> 详见 [`references/phase5-risk-modeling.md`](references/phase5-risk-modeling.md)

```
1. 根据引擎类型执行路由提取算子
2. 提取每个端点的参数列表
3. 计算五维风险评分
4. 生成 Audit-Context.json
```

### Step 2: 代码嗅探（对每个 HIGH/CRITICAL 端点）

```
for each endpoint where priority >= HIGH:
    read controller method body
    read service method body (via LSP)
    scan for sink patterns:
        - SQL: Statement, createQuery, ${}
        - File: new File, FileInputStream, Paths.get
        - HTTP: RestTemplate, HttpClient, WebClient
        - Deserialize: readObject, parseObject, enableDefaultTyping
        - Template: getTemplate, evaluate, th:utext, ?new()
        - Expression: parseExpression, OgnlUtil, MVEL, bsh.Interpreter, Eval.me, GroovyShell, ScriptEngine
        - JNDI: InitialContext.lookup, JndiTemplate.lookup
        - XXE: DocumentBuilderFactory, SAXParser, XMLReader
        - File Upload: MultipartFile, transferTo
        - LDAP: DirContext.search, LdapTemplate
        - Command: Runtime.exec, ProcessBuilder
        - Redirect: sendRedirect, RedirectView, forward
        - Auth: OAuth2, SAML, CAS, Shiro, SpringSecurity, JWT, OIDC
        - RPC: @DubboService, @DubboReference, Thrift, gRPC, HSF, Motan
        - DB Protocol: JDBC URL, autoDeserialize, COPY, Redis, MongoDB, Elasticsearch
        - MQ: Kafka, RabbitMQ, RocketMQ, ActiveMQ
        - Cache: JdkSerializationRedisSerializer, Memcached, Ehcache, Caffeine
    output: sniff_tags[] for this endpoint
```

### Step 3: 决策引擎（动态路由）

> 详见 [`references/decision-engine.md`](references/decision-engine.md)

```
load decision rules (built-in + extension)
for each endpoint:
    matched_branches = match_rules(endpoint.sniff_tags)
    if PARALLEL_BRANCHES:
        execute all matched branches in parallel
    else:
        execute branches sequentially
```

**内置决策规则**:

| 嗅探标签 | 触发分支 | 分支文件 |
|----------|----------|----------|
| SQL_CONCAT, SQL_STATEMENT | SQL注入审计 | `references/branch-sqli.md` |
| FILE_PATH, FILE_INPUT | 路径穿越审计 | `references/branch-path-traversal.md` |
| HTTP_CLIENT, URL_OPEN | SSRF审计 | `references/branch-ssrf.md` |
| DESERIALIZE, READ_OBJECT | 反序列化审计 | `references/branch-deserialization.md` |
| TEMPLATE_RENDER, TH_UTEXT, FREEMARKER_NEW, VELOCITY_REFLECT | SSTI模板注入审计 | `references/branch-ssti.md` |
| EXPRESSION_PARSE, OGNL, EL_INJECT, MVEL_EVAL, BEANSHELL, GROOVY_EVAL, NASHORN | 表达式注入审计 | `references/branch-expression.md` |
| JNDI_LOOKUP | JNDI注入审计 | `references/branch-jndi.md` |
| XXE_PARSE | XXE审计 | `references/branch-xxe.md` |
| FILE_UPLOAD | 文件上传审计 | `references/branch-file-upload.md` |
| LDAP_SEARCH | LDAP注入审计 | `references/branch-ldap.md` |
| AUTH_MISSING, NO_ROLE | IDOR/越权审计 | `references/branch-idor.md` |
| CRYPTO_WEAK, HARDCODED_KEY | 密码学审计 | `references/branch-crypto.md` |
| COMMAND_EXEC, PROCESS_BUILDER | 命令注入审计 | `references/branch-command.md` |
| REDIRECT, FORWARD | 重定向审计 | `references/branch-redirect.md` |
| OAUTH2, SAML, CAS_TICKET, SHIRO, SPRING_SECURITY, JWT_ADVANCED, OIDC, KERBEROS | 认证协议审计 | `references/branch-auth-protocol.md` |
| DUBBO_SERVICE, DUBBO_CONSUMER, THRIFT, GRPC_SERVICE, HSF, MOTAN, SOFA_RPC | RPC框架审计 | `references/branch-rpc-framework.md` |
| JDBC_URL, MYSQL_DESER, POSTGRES_COPY, REDIS_PROTO, MONGO_NOSQL, ELASTICSEARCH_INJECT | 数据库协议审计 | `references/branch-db-protocol.md` |
| KAFKA_CONSUMER, KAFKA_PRODUCER, RABBITMQ, ROCKETMQ_DESER, ACTIVEMQ, PULSAR | 消息队列审计 | `references/branch-mq-deserialize.md` |
| REDIS_DESER, REDIS_COMMAND, MEMCACHED, CACHE_POISON, EHCACHE, CAFFEINE | 缓存注入审计 | `references/branch-cache-inject.md` |

**扩展接口**:

用户可在项目根目录放置 `.audit-extensions/rules.json` 自定义规则：

```json
{
  "custom_rules": [
    {
      "name": "自定义审计分支",
      "trigger_tags": ["CUSTOM_SINK"],
      "branch_file": ".audit-extensions/branch-custom.md",
      "priority": 10
    }
  ],
  "tag_detectors": [
    {
      "tag": "CUSTOM_SINK",
      "pattern": "com\\.example\\.DangerousAPI\\.\\w+",
      "description": "检测自定义危险API"
    }
  ]
}
```

### Step 4: 分支审计执行

每个分支独立执行，可能产生以下请求：

```
分支审计结果:
├─ 漏洞确认 → 记录到审计报告
├─ 需要更多LSP信息 → 生成 Backtrack-Request
├─ 发现关联端点 → 生成 Lateral-Expand-Request
└─ 无发现 → 标记该分支完成
```

### Step 5: 回溯与横向扩展循环

```
backtrack_count = 0
expand_queue = []

while (backtrack_requests or expand_requests) and backtrack_count < MAX_BACKTRACK:
    if backtrack_requests:
        send Backtrack-Request to dispatcher
        receive LSP trace results from Phase 4
        re-evaluate affected branches
        backtrack_count += 1

    if expand_requests:
        add new endpoints to audit queue
        execute Step 2-4 for new endpoints

if backtrack_count >= MAX_BACKTRACK:
    trigger ERR-BACKTRACK-LIMIT
    record remaining untraced items
```

### Step 6: 生成动态审计报告

```
for each endpoint:
    record audit path (which branches were triggered and why)
    record branch switch decisions
    record backtrack history
output final vulnerability list + PoC
```

## 强制输出模板

> 详细输出模板见 [`references/phase5-api-output.md`](references/phase5-api-output.md)

## 输出示例

```json
{
  "phase": "Phase 5",
  "audit_meta": {
    "total_endpoints": 42,
    "high_risk_endpoints": 8,
    "backtrack_count": 3,
    "branches_triggered": ["sqli", "path-traversal", "ssrf"]
  },
  "endpoint_audits": [
    {
      "asset_id": "ROUTE-001",
      "path": "GET /api/v1/backup/download/{fileId}",
      "risk_score": 75,
      "sniff_tags": ["FILE_PATH", "AUTH_MISSING"],
      "branches_triggered": ["path-traversal", "idor"],
      "audit_path": "嗅探→路径穿越分支→回溯请求(P4)→IDOR分支",
      "findings": [
        {
          "type": "路径穿越",
          "status": "FAIL",
          "evidence": "FileService.java:42",
          "poc": "GET /api/v1/backup/download/..%2F..%2Fetc%2Fpasswd"
        }
      ],
      "backtrack_history": [
        {
          "round": 1,
          "request": "追踪 FileService.download 参数来源",
          "result": "确认 fileId 直接来自 @PathVariable，无净化"
        }
      ]
    }
  ],
  "circuit_breakers": [],
  "unresolved_items": []
}
```
