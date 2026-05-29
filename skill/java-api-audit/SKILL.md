---
name: java-api-audit
description: Load when you need to perform Source → Sink taint analysis on Java API endpoints, focusing on parameter controllability and business security. Use after java-api-discovery identifies HIGH/CRITICAL risk endpoints, or when dynamic code-driven security audit is needed
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
---

# Java API 正向污点审计

## 核心规则

1. **正向追踪**：始终 Source → Processing → Sink，禁止从 Sink 反推 Source
2. **逐一审计**：必须按 P0 → P1 → P2 优先级逐一审计每个端点，不得跳过、不得合并、不得选择"代表性"端点
3. **参数可控性优先**：先确认参数是否用户可控，再追踪其流向
4. **动态决策**：根据代码嗅探标签动态路由到对应审计分支
5. **业务安全绑定**：每个漏洞必须关联业务场景，不得脱离上下文报告技术发现
6. **输出纯净**：phase4-api-audit.md 只含审计详情，最终报告只含汇总统计，不得互相重复
7. **输出统一**：所有输出为 Markdown 文件，存放在 `output/` 目录
8. **全路径+行号**：每个审计步骤必须输出类的全限定名和行号，每一步函数调用必须有说明，关键点必须标注
9. **参数消毒分析**：对每个可控参数，必须分析从 Source 到 Sink 路径上是否存在消毒/净化操作，消毒是否可绕过
10. **配置文件关联**：必须结合 phase1-recon.md 中的 Config_Analysis，分析配置文件对 API 行为的影响
11. **完整链路**：正向链路必须从 Source 点到 Sink 点完整覆盖，中间每一步的方法调用、文件路径、行号都必须标注
12. **框架防护关联**：每个端点必须分析其受到的四层防护（Filter/SecurityFilterChain/Interceptor/启动安全配置），输出防护矩阵和综合防护等级
13. **三层审计结果引用**：必须引用 phase2 的三层审计结果（P1-P7 Filter 类代码 + FC1-FC6 注册配置 + SC1-SC10 SecurityFilterChain 配置），不得仅引用 P1-P7
14. **确定性分级**：每个审计步骤必须标注确定性等级（DETERMINISTIC/HEURISTIC/SUBJECTIVE），非 DETERMINISTIC 步骤必须输出置信度（CONFIRMED/LIKELY/POSSIBLE）和人工验证方法
15. **上下文敏感消毒**：消毒有效性必须结合 Sink 类型评估，禁止脱离 Sink 上下文判断消毒是否有效（详见 references/taint-semantics.md）
16. **跨请求追踪**：对存储型漏洞（Stored XSS、二阶注入、Session 污染），必须追踪数据在 DB/Session/缓存中的跨请求流向（详见 references/cross-request-tracking.md）
17. **可执行测试资产**：PoC 必须为可执行的 curl 命令格式，包含认证步骤、完整 URL、预期响应特征；必须为每个漏洞类型生成针对性 Fuzzing 字典

## 输入

- `output/api-risk-assessment.md`（来自 java-api-discovery，含风险评分 + 业务上下文的 API 清单）
- `output/phase1-recon.md`（资产台账 + 配置文件分析 + 启动时安全配置资产）
- `output/phase2-filter-audit.md`（三层审计：Filter 类代码 P1-P7 + Filter 注册配置 FC1-FC6 + SecurityFilterChain 配置 SC1-SC10 + 执行顺序 + 可达性评估）
- `output/phase2b-startup-config-audit.md`（启动时安全配置审计 BC1-BC8）
- `output/phase3-interceptor-audit.md`（框架层已知风险 + 执行顺序 + 可达性评估）

## 工作流程

### 检查点 0：威胁建模（前置）

```
输入: output/phase1-recon.md + output/phase2-filter-audit.md + output/phase3-interceptor-audit.md + output/api-risk-assessment.md
输出: output/threat-model.md

执行 STRIDE 威胁建模（详见 references/threat-modeling.md）:
  1. 攻击面枚举: 未认证端点、认证后端点、数据层、集成层
  2. STRIDE 威胁识别: Spoofing/Tampering/Repudiation/InfoDisclosure/DoS/EoP
  3. 攻击树构建: 对 Top 3 高价值目标构建攻击路径
  4. 审计优先级调整: 基于攻击树补充/调整三维评分队列

确定性标注:
  - 攻击面枚举: DETERMINISTIC（配置解析 + 注解扫描）
  - STRIDE 威胁识别: HEURISTIC（模式匹配，可能遗漏非典型威胁）
  - 攻击树构建: SUBJECTIVE（需安全专家经验，AI 输出需人工审核）
  - 优先级调整: SUBJECTIVE（多因素权衡）

输出: 威胁建模报告 + 调整后的审计队列
```

### 检查点 1：审计队列生成

```
输入: output/api-risk-assessment.md
处理:
  - 提取 P0 (CRITICAL) 端点列表 → 审计队列
  - 提取 P1 (HIGH) 端点列表 → 追加到审计队列
  - 提取 P2 (MEDIUM) 端点列表 → 追加到审计队列
  - 按优先级排序：P0 → P1 → P2

输出: 审计队列列表（必须包含所有 P0 + P1 端点，不得遗漏）
```

### 检查点 2：Source 识别与参数可控性验证

```
确定性: DETERMINISTIC（注解扫描 + 参数提取均为正则匹配）

对队列中每个端点:

1. 读取 Controller 方法体
2. 识别所有 Source（用户可控输入点）:
   - @RequestParam → 用户可控
   - @RequestBody → 用户可控
   - @PathVariable → 用户可控
   - @RequestHeader → 用户可控
   - @CookieValue → 用户可控
   - request.getParameter() → 用户可控
   - request.getInputStream()/getReader() → 用户可控
   - 方法内硬编码 → 不可控（跳过）

3. 对每个 Source 记录:
   - 参数名、类型、来源注解
   - 参数业务含义（从命名/注释/DTO 推断，如 "云服务商编码" 而非仅 "String"）
   - 是否经过校验（@Valid/@Pattern/@Size/自定义校验器）
   - 校验强度（强/弱/无）
   - 校验具体内容（正则表达式、长度限制、白名单等）
   - 所在文件全路径 + 行号

4. 业务上下文记录:
   - 该端点的业务用途（一句话说明）
   - 该端点调用的 Service 方法及业务操作类型
   - 该端点操作的数据对象及敏感度
```

### 检查点 3：Processing 链追踪

```
确定性: 混合（见下方各子步骤标注）

对每个可控 Source:

1. 读取方法体内对该参数的处理:
   - 直接传递 → 追踪到下一层调用，记录目标方法全路径 + 行号 [DETERMINISTIC]
   - 字符串拼接 → 标记为危险处理，记录拼接位置行号 [DETERMINISTIC]
   - 格式化/编码 → 查 taint-semantics.md 矩阵评估是否有效净化 [HEURISTIC]
   - 条件分支 → 评估分支是否可绕过，记录分支条件行号 [HEURISTIC]
   - 类型转换 → 查 taint-semantics.md 评估是否消除污点 [DETERMINISTIC: 数字解析/枚举; HEURISTIC: 其他]
   - 集合操作 → 追踪参数是否进入集合后在循环中被使用 [HEURISTIC]

2. 若调用其他方法:
   - 读取被调用方法体
   - 追踪参数在被调用方法中的流向
   - 最多追踪 3 层调用链
   - 每层调用必须记录: 全限定类名.方法名(参数类型):行号

3. 参数消毒分析（对每个可控参数必须执行）:
   - **必须结合 Sink 类型评估消毒有效性**（详见 references/taint-semantics.md 第 2 节矩阵）
   - 从 Source 到 Sink 路径上，扫描以下消毒操作:
     * 输入校验: @Valid, @Pattern, @Size, 自定义 Validator
     * 编码转义: HtmlUtils.htmlEscape, StringEscapeUtils, URLEncoder.encode
     * 白名单过滤: 枚举转换, switch-case 映射, Map.get 查找
     * 参数化查询: PreparedStatement, JPA Criteria, MyBatis #{}
     * 类型强转: Long.parseLong, Integer.valueOf (限制为数字类型)
   - 对发现的消毒操作评估:
     * **消毒对当前 Sink 类型是否有效**（查矩阵，如 htmlEscape 对 SQL Sink 无效）[DETERMINISTIC: 矩阵中有明确条目; HEURISTIC: 自定义消毒函数]
     * 消毒是否完整（是否覆盖所有攻击向量）[HEURISTIC]
     * 消毒是否可绕过（编码绕过、截断绕过、类型混淆）[HEURISTIC]
     * 消毒后数据是否再次被拼接/修改 [DETERMINISTIC]
   - 输出格式:
     * 消毒方式: 具体方法名
     * 消毒位置: 全限定类名:行号
     * Sink 类型: SQL/HTML/CMD/LDAP/URL/FILE
     * 消毒对该 Sink 是否有效: 有效/无效/部分有效（查矩阵）
     * 消毒评估: 完整/不完整/可绕过 + 理由
     * 置信度: CONFIRMED/LIKELY/POSSIBLE

4. 记录 Processing 链:
   每一步必须包含:
   - 步骤编号（Step 1, Step 2, ...）
   - 操作说明（"用户输入进入方法"、"参数直接拼接 SQL"、"调用 executeQuery 执行"）
   - 代码位置（全限定类名:行号）
   - 关键代码片段（1-2 行）
   - 风险标注（【Source】、【危险】、【净化】、【可绕过】、【安全】、【Sink】）
   - 参数状态（参数当前的值/形态，如 "原始用户输入"、"已 URL 编码"、"已拼接到 SQL"）
```

### 检查点 4：Sink 验证与代码嗅探

```
确定性: DETERMINISTIC（Sink 模式匹配为正则搜索）; 污点到达判定为 HEURISTIC

对 Processing 链的终点，扫描以下 Sink 模式:

| Sink 类型 | 代码特征 |
|-----------|----------|
| SQL 执行 | Statement.executeQuery, createQuery, "${}" |
| 文件操作 | new File, FileInputStream, Paths.get, transferTo |
| HTTP 请求 | RestTemplate, HttpClient, WebClient, URL.openConnection |
| 反序列化 | readObject, fromXML, parseObject, enableDefaultTyping |
| 模板渲染 | getTemplate, th:utext, ?new(), VelocityEngine |
| 表达式 | parseExpression, OgnlUtil, MVEL.eval, Eval.me, GroovyShell |
| JNDI | InitialContext.lookup, JndiTemplate.lookup |
| XML 解析 | DocumentBuilderFactory, SAXParser, XMLReader |
| 命令执行 | Runtime.exec, ProcessBuilder |
| 重定向 | sendRedirect, RedirectView, forward |
| LDAP | DirContext.search, LdapTemplate |

若发现 Sink:
  - 确认参数是否未经净化直接到达 Sink
  - 若到达 → 漏洞确认，记录正向链路
  - 若被净化 → 评估净化是否可绕过
  - 记录 Sink 位置: 全限定类名:行号

Sink 路径输出格式（强制）:
  完整路径: {Source文件全路径}:{Source行号} → {中间方法1全路径}:{行号} → {中间方法2全路径}:{行号} → {Sink文件全路径}:{Sink行号}
  示例: com.huawei.csb.controller.GatewayController.java:45 → com.huawei.csb.service.CsbGatewayService.invokeCsbGateway():78 → com.huawei.csb.dao.VendorRepository.findByVendor():120
  问题描述: {Sink文件全路径} 的 {方法名} 方法，第 {行号} 行，存在 {漏洞类型}
```

### 检查点 5：动态决策与分支审计

```
确定性: DETERMINISTIC（标签匹配为正则搜索）; 分支选择为 HEURISTIC
根据代码嗅探标签，动态路由到对应审计分支:

| 嗅探标签 | 触发分支 | 优先级 |
|----------|----------|--------|
| SQL_CONCAT, SQL_STATEMENT | SQL注入审计 | 1 |
| FILE_PATH, FILE_INPUT | 路径穿越审计 | 2 |
| HTTP_CLIENT, URL_OPEN | SSRF审计 | 2 |
| DESERIALIZE, READ_OBJECT | 反序列化审计 | 1 |
| TEMPLATE_RENDER, TH_UTEXT | SSTI审计 | 1 |
| EXPRESSION_PARSE, OGNL | 表达式注入审计 | 1 |
| JNDI_LOOKUP | JNDI注入审计 | 1 |
| XXE_PARSE | XXE审计 | 1 |
| FILE_UPLOAD | 文件上传审计 | 2 |
| LDAP_SEARCH | LDAP注入审计 | 2 |
| AUTH_MISSING, NO_ROLE | IDOR/越权审计 | 3 |
| CRYPTO_WEAK, HARDCODED_KEY | 密码学审计 | 3 |
| COMMAND_EXEC, PROCESS_BUILDER | 命令注入审计 | 1 |
| REDIRECT, FORWARD | 重定向审计 | 3 |

按优先级排序后串行执行各分支审计
```

### 检查点 6：框架防护层关联分析

```
确定性: DETERMINISTIC（URL 模式匹配 + 审计结果引用）; 综合防护等级判定为 HEURISTIC
输入:
  - output/phase2-filter-audit.md（三层审计结果 + 执行链顺序）
  - output/phase2b-startup-config-audit.md（启动时安全配置审计）
  - output/phase3-interceptor-audit.md（Interceptor 审计 + 执行链顺序）

对每个审计的端点，分析其受到的框架层防护情况：

1. Filter 防护覆盖分析：
   - 该端点路径被哪些 Filter 覆盖？（从执行链顺序中匹配 URL 模式）
   - 覆盖的 Filter 是否有 FAIL 断言？
   - FAIL 断言的可达性是什么？（REACHABLE/PARTIALLY_REACHABLE/UNREACHABLE）
   - 例如: 端点 /api/users 被 AuthFilter(order=1) 覆盖，AuthFilter P4=FAIL 但 UNREACHABLE

2. SecurityFilterChain 防护分析：
   - 该端点路径匹配哪个 SecurityFilterChain？（从 securityMatcher 匹配）
   - 该 SecurityFilterChain 的 SC1-SC10 审计结果如何？
   - CSRF 是否保护该端点？（SC1 结果）
   - 该端点是否需要认证？（SC2 permitAll 路径交叉验证）
   - 安全头是否保护该端点？（SC6 结果）

3. Interceptor 防护覆盖分析：
   - 该端点路径被哪些 Interceptor 覆盖？
   - Interceptor 的 I1-I7 审计结果如何？
   - 是否有 FAIL 断言影响该端点？

4. 启动时安全配置关联：
   - 该端点的 Service 层是否使用了启动时初始化的安全 Bean？
   - 例如: 认证 API 使用了 BC1=FAIL 的 PasswordEncoder
   - 例如: JWT API 使用了 BC2=FAIL 的 TokenProvider（硬编码密钥）

5. 综合防护评估：
   对每个端点输出防护矩阵：

   | 防护层 | 覆盖组件 | 审计结果 | 对该端点的影响 |
   |--------|----------|----------|---------------|
   | Filter 层 | AuthFilter | P4=FAIL(UNREACHABLE) | 无影响（被前置拦截） |
   | SecurityFilterChain | SEC-CONFIG-001 | SC1=FAIL(CSRF禁用) | 该端点无 CSRF 保护 |
   | Interceptor 层 | AuthInterceptor | I1=FAIL(无鉴权) | 该端点无额外鉴权 |
   | 启动配置 | passwordEncoder | BC1=FAIL(NoOp) | 密码明文存储 |

   综合防护等级：
   - WELL_PROTECTED: 所有防护层 PASS 或 FAIL 但 UNREACHABLE
   - PARTIALLY_PROTECTED: 部分防护层 FAIL 且 REACHABLE/PARTIALLY_REACHABLE
   - UNPROTECTED: 关键防护层（CSRF、认证、安全头）FAIL 且 REACHABLE
```

### 检查点 7：配置文件关联分析

```
确定性: DETERMINISTIC（配置键值匹配）; 配置对漏洞影响评估为 HEURISTIC
输入: output/phase1-recon.md 中的 Config_Analysis

对每个审计的端点:

1. 检查 API 行为是否受配置文件控制:
   - 追踪 Controller → Service → 配置注入点（@Value, @ConfigurationProperties, Environment.getProperty）
   - 识别 Service 层是否读取了配置项来影响行为

2. 关联配置风险项:
   - 若 Config_Analysis 中存在 HIGH 风险配置，检查是否有 API 受影响
   - 例如: CORS 配置 allowed-origins=* → 所有 API 受影响
   - 例如: Actuator 暴露 env 端点 → 可能泄露数据库密码
   - 例如: 文件上传无大小限制 → 文件上传 API 存在 DoS 风险

3. 配置对漏洞利用的影响:
   - 配置是否加剧漏洞风险（如超时配置导致 SSRF 可利用）
   - 配置是否可缓解漏洞（如限流配置降低 DoS 影响）

4. 输出格式:
   - 关联配置键: 配置值
   - 配置文件: 文件名:行号
   - 影响说明: 配置如何影响该 API 的安全性
```

### 检查点 8：业务安全评估

```
确定性: SUBJECTIVE（业务影响评估依赖对业务逻辑的理解，AI 输出需人工审核）
对每个确认的漏洞:

1. 关联业务场景:
   - 该端点的业务用途是什么？（从检查点 2 的业务上下文获取）
   - 该端点操作的数据对象及敏感度
   - 被利用后对业务的影响？（数据泄露/篡改/服务中断/权限提升）
   - 攻击者需要什么前提条件？

2. 评估实际风险:
   - 是否需要认证？
   - 是否需要特定角色？
   - 是否有补偿控制（日志、限流、WAF）？
   - 配置文件是否加剧/缓解风险？

3. 生成 PoC:
   - 基于正向链路构造**可执行的 curl 命令**
   - 包含: 认证步骤（先登录获取 Cookie/Token）→ 攻击请求 → 预期响应特征
   - 格式:
     ```bash
     # Step 1: 认证
     curl -c cookies.txt -X POST 'http://target:8080/login' -d 'username=admin&password=admin'
     # Step 2: 攻击
     curl -b cookies.txt -X POST 'http://target:8080/endpoint' -d 'param=PAYLOAD'
     # 预期: HTTP 200, 响应体包含 {特征字符串}
     ```
   - 验证标准: 明确说明如何确认漏洞被成功触发（响应码、响应体特征、时间延迟等）
```

### 检查点 9：跨请求污点追踪

```
确定性: 混合（见 references/cross-request-tracking.md 第 4 节）

对以下类型的漏洞，必须执行跨请求追踪:

1. 存储型 XSS:
   - 扫描所有写入 DB 的 tainted 数据（INSERT/UPDATE）
   - 扫描所有从 DB 读取并渲染到模板的数据（th:utext / 无转义输出）
   - 关联写入端点和读取端点

2. 二阶 SQL 注入:
   - 扫描 tainted 数据存入 DB 的路径
   - 扫描从 DB 读出后拼接到 SQL 的路径
   - 关联两个端点

3. Session 污染:
   - 扫描 setAttribute(tainted) 的端点
   - 扫描 getAttribute 后到达 Sink 的端点
   - 关联两个端点

4. 缓存投毒:
   - 扫描 @CachePut / RedisTemplate.set 的 tainted 数据
   - 扫描 @Cacheable / RedisTemplate.get 后到达 Sink 的端点

输出: 跨请求污点链路列表（详见 references/cross-request-tracking.md 第 3 节格式）
```

### 检查点 10：业务逻辑漏洞审计

```
确定性: 混合（见 references/business-logic-audit.md 第 4 节）

对业务操作类端点，按 6 种类型逐一检查:

1. 竞态条件: UPDATE 操作是否有锁机制
2. 状态机违规: 状态转换是否验证前置状态
3. 价格/金额篡改: 价格是否来自客户端
4. 工作流绕过: 最终操作是否验证审批状态
5. 批量枚举: ID 是否可预测 + 是否有频率限制 + 是否有所属权检查
6. 优惠券/折扣滥用: 使用次数是否限制

输出: 业务逻辑风险清单（详见 references/business-logic-audit.md 第 2 节格式）
```

### 检查点 11：生成审计报告

```
确定性: DETERMINISTIC（报告生成为结构化输出）

输出文件: output/phase4-api-audit.md

内容（按顺序）:
  1. 威胁建模摘要（来自检查点 0 的 attack tree + STRIDE 威胁清单）

  2. 路由映射表（所有 P0+P1 端点 + 风险等级 + 业务用途）

  3. 每个端点的独立审计章节（必须包含以下结构）:

     ### POST /endpoint/path — CRITICAL (Score)
     
     **业务用途**: 一句话说明该 API 的业务功能
     **Controller**: 全限定类名 (文件名:行号)
     **认证**: 是/否（来源: SecurityFilterChain SC2 审计结果）
     **过滤**: 是/否（来源: Filter 层 P1-P7 审计结果）
     **鉴权**: 是/否（来源: Interceptor 层 I1-I7 审计结果）
     **关联配置**: 列出影响该 API 行为的配置项（配置键=配置值，文件名:行号）
     
     **框架防护分析**:
     | 防护层 | 覆盖组件 | 审计结果 | 可达性 | 对该端点的影响 |
     
     **综合防护等级**: WELL_PROTECTED / PARTIALLY_PROTECTED / UNPROTECTED
     
     **参数分析**:
     | 参数 | 类型 | 业务含义 | Source 识别 | 校验方式 | 是否消毒 | Sink 类型 | 消毒对 Sink 有效性 | Processing 链 | Sink | 结论 |
     
     **参数消毒分析**:
     | 参数 | 消毒方式 | 消毒位置 | Sink 类型 | 对该 Sink 有效性 | 消毒评估 | 置信度 | 理由 |
     
     **正向链路**:
     Step N: 操作说明
       位置: 全限定类名:行号
       代码: 1-2 行代码片段
       说明: 操作说明
       确定性: DETERMINISTIC / HEURISTIC / SUBJECTIVE
       参数状态: 参数当前的值/形态
       风险标注: 【Source】/【危险】/【净化】/【可绕过】/【安全】/【Sink】
     
     **完整 Sink 路径**: 全路径 A.java:行号 → B.java:行号 → C.java:行号
     
     **整体置信度**: CONFIRMED / LIKELY / POSSIBLE
     **置信度依据**: 列出每个步骤的确定性等级汇总
     
     **业务影响**: 关联业务场景的影响描述
     
     **配置文件关联**: 关联的配置项及影响说明
     
     **PoC（可执行 curl 命令）**:
     ```bash
     # Step 1: 认证
     curl -c cookies.txt -X POST 'http://target:8080/login' -d 'username=xxx&password=xxx'
     # Step 2: 攻击
     curl -b cookies.txt -X POST 'http://target:8080/endpoint' -d 'param=PAYLOAD'
     # 预期: HTTP {code}, 响应体包含 {特征}
     ```
     
     **验证标准**: 如何确认漏洞被成功触发（响应码、响应体特征、时间延迟）

  4. 跨请求污点链路汇总（来自检查点 9）:
     | # | 漏洞类型 | 写入端点 | 存储介质 | 读取端点 | Sink | 置信度 | PoC |

  5. 业务逻辑风险清单（来自检查点 10）:
     | # | 漏洞类型 | 端点 | 代码证据 | 置信度 | 严重度 | PoC 思路 |

  6. 框架防护覆盖汇总:
     | 端点 | Filter 覆盖 | SecurityFilterChain | Interceptor 覆盖 | 综合防护等级 | 关键缺陷 |

  7. 配置文件风险关联表

  8. 启动时安全配置关联表

  9. Fuzzing 字典（按漏洞类型）:
     | 漏洞类型 | 目标参数 | Fuzzing Payload 示例 | 预期触发条件 |
     |----------|----------|---------------------|-------------|
     | SQL注入 | name | ' OR 1=1 -- | 响应包含额外数据 |
     | SQL注入 | name | ' UNION SELECT null,null -- | 响应列数匹配 |
     | XSS | content | <script>alert(1)</script> | 响应体包含未转义标签 |
     | 路径穿越 | fullName | ../../etc/passwd | 响应包含 passwd 内容 |
     | SSRF | url | http://127.0.0.1:8080/actuator/env | 响应包含 actuator 数据 |

  10. 漏洞汇总清单（一行一条）:
      # | 类型 | 严重度 | 端点 | 置信度 | 完整 Sink 路径 | PoC 摘要

  11. 业务安全评估表
  12. 修复建议

禁止:
  - 不得遗漏审计队列中的任何 P0 或 P1 端点
  - 不得合并多个端点到一个章节
  - 不得包含评分公式或因子定义
  - 不得省略类全路径和行号
  - 不得省略步骤说明
  - 参数表不得省略"业务含义"和"是否消毒"列
  - 不得省略"完整 Sink 路径"段落
  - 不得省略"配置文件关联"段落
  - 不得省略"整体置信度"和"置信度依据"
  - PoC 不得为 payload 片段，必须为可执行 curl 命令
  - 不得省略"验证标准"
  - 不得省略 Fuzzing 字典
```

## 输出格式强制要求

每个端点的正向链路必须包含以下元素，缺一不可:

| 元素 | 格式示例 | 必须 |
|------|----------|------|
| 步骤编号 | Step 1, Step 2, ... | ✅ |
| 操作说明 | "用户输入进入方法"、"参数直接拼接 SQL" | ✅ |
| 类全路径 | `org.owasp.webgoat.lessons.xxx.Controller.java` | ✅ |
| 行号 | `:43` | ✅ |
| 关键代码 | 1-2 行代码片段 | ✅ |
| 风险标注 | 【Source】、【危险】、【净化】、【可绕过】、【安全】、【Sink】 | ✅ |
| 参数状态 | "原始用户输入"、"已 URL 编码"、"已拼接到 SQL" | ✅ |

每个端点的审计章节必须包含以下段落，缺一不可:

| 段落 | 说明 | 必须 |
|------|------|------|
| 业务用途 | 一句话说明 API 业务功能 | ✅ |
| 框架防护分析表 | Filter/SecurityFilterChain/Interceptor/启动配置 四层防护矩阵 | ✅ |
| 综合防护等级 | WELL_PROTECTED/PARTIALLY_PROTECTED/UNPROTECTED | ✅ |
| 参数分析表 | 含业务含义、校验方式、是否消毒、Sink 类型、消毒对 Sink 有效性列 | ✅ |
| 参数消毒分析表 | 消毒方式、位置、Sink 类型、对该 Sink 有效性、评估、置信度 | ✅ |
| 正向链路 | Step 1~N 完整 Source→Sink，每步含确定性标注 | ✅ |
| 完整 Sink 路径 | 全路径 A.java:行号 → B.java:行号 → C.java:行号 | ✅ |
| 整体置信度 | CONFIRMED/LIKELY/POSSIBLE + 依据 | ✅ |
| 业务影响 | 关联业务场景的影响描述 | ✅ |
| 配置文件关联 | 关联的配置项及影响说明 | ✅ |
| PoC (curl) | 可执行 curl 命令，含认证步骤 + 攻击请求 + 预期响应 | ✅ |
| 验证标准 | 如何确认漏洞被成功触发 | ✅ |

## 常见错误

| 错误场景 | 正确做法 |
|----------|----------|
| 从 Statement.executeQuery 反推用户输入 | 必须从 @RequestParam 开始正向追踪 |
| 报告"存在 SQL 注入"但不说明业务影响 | 必须关联业务场景（如"用户查询接口可拖库"） |
| 忽略参数校验直接标记漏洞 | 先评估 @Valid/@Pattern 是否有效 |
| 追踪超过 3 层调用链 | 最多 3 层，超出则标记"需进一步追踪" |
| 脱离框架层风险孤立审计 API | 必须参考 phase2/phase3 的已知风险及可达性评估进行加权 |
| 忽略框架层可达性评估结果 | 若 phase2/phase3 标记 UNREACHABLE，对应端点的过滤/鉴权因子不应被强制加权 |
| 跳过 P0/P1 端点，只审计"代表性"端点 | 必须逐一审计队列中的每个端点 |
| 合并多个端点到一个审计章节 | 每个端点必须有独立章节 |
| phase4 输出中包含评分公式 | 评分公式在 references 中，输出只含结果 |
| 省略类全路径，只写类名 | 必须写全限定类名（含 package） |
| 省略行号 | 每个步骤必须标注行号 |
| 只写"参数传递到方法"，不说明具体方法 | 必须写明方法名、参数、行号 |
| 不标注风险点 | 每个步骤必须标注【Source】/【危险】/【净化】/【Sink】 |
| 参数分析只写技术类型不写业务含义 | 参数表必须包含"业务含义"列，说明参数的业务用途 |
| 不分析参数消毒情况 | 必须包含"参数消毒分析"段落，逐一分析每个可控参数的消毒情况 |
| Sink 路径只写终点不写完整链路 | 必须输出从 Source 到 Sink 的完整路径，每一步含文件全路径+行号 |
| 忽略配置文件对 API 安全的影响 | 必须包含"配置文件关联"段落，结合 phase1 的 Config_Analysis |
| 不写业务用途说明 | 每个端点必须在开头标注"业务用途" |
| 不分析框架防护层对端点的覆盖 | 必须包含"框架防护分析"表格，列出 Filter/SecurityFilterChain/Interceptor/启动配置四层防护矩阵 |
| 认证/过滤/鉴权不标注来源 | 必须标注来源（如"来源: SecurityFilterChain SC2 审计结果"） |
| 忽略启动时安全配置对 API 的影响 | 必须关联 phase2b 的 BC1-BC8 审计结果（如 PasswordEncoder、TokenProvider） |
| 不评估综合防护等级 | 每个端点必须输出综合防护等级（WELL_PROTECTED/PARTIALLY_PROTECTED/UNPROTECTED） |
| 脱离 Sink 类型判断消毒有效性 | htmlEscape 对 SQL 无效、URLEncode 对 CMD 无效 — 必须查 taint-semantics.md 矩阵 |
| PoC 只写 payload 片段 | 必须为可执行 curl 命令，含认证步骤 + 攻击请求 + 预期响应特征 |
| 不标注步骤确定性 | 每个 Step 必须标注 DETERMINISTIC/HEURISTIC/SUBJECTIVE |
| 不输出整体置信度 | 每个漏洞必须输出 CONFIRMED/LIKELY/POSSIBLE + 依据 |
| 忽略跨请求污点 | 存储型 XSS/二阶注入/Session 污染必须执行跨请求追踪 |
| 忽略业务逻辑漏洞 | 必须对业务操作类端点执行竞态/状态机/价格篡改/工作流绕过检查 |
| 不做威胁建模直接审计 | 必须先执行 STRIDE 威胁建模，生成攻击树指导审计优先级 |
| 不生成 Fuzzing 字典 | 必须按漏洞类型生成针对性 Fuzzing payload 字典 |
| 不写验证标准 | 每个 PoC 必须说明如何确认漏洞被成功触发 |

## 参考

- 决策引擎规则详见 `references/decision-engine.md`
- 污点语义模型（消毒×Sink 有效性矩阵 + 传播/消除规则）详见 `references/taint-semantics.md`
- 跨请求污点追踪方法论详见 `references/cross-request-tracking.md`
- STRIDE 威胁建模方法论详见 `references/threat-modeling.md`
- 业务逻辑漏洞审计方法论详见 `references/business-logic-audit.md`
- 审计分支文件详见 `references/branch-*.md`
