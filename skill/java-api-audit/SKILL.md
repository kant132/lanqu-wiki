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

## 输入

- `output/api-risk-assessment.md`（来自 java-api-discovery，含风险评分 + 业务上下文的 API 清单）
- `output/phase1-recon.md`（资产台账 + 配置文件分析结果 Config_Analysis）
- `output/phase2-filter-audit.md`（框架层已知风险）
- `output/phase3-interceptor-audit.md`（框架层已知风险）

## 工作流程

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
对每个可控 Source:

1. 读取方法体内对该参数的处理:
   - 直接传递 → 追踪到下一层调用，记录目标方法全路径 + 行号
   - 字符串拼接 → 标记为危险处理，记录拼接位置行号
   - 格式化/编码 → 评估是否有效净化，记录净化方法行号
   - 条件分支 → 评估分支是否可绕过，记录分支条件行号
   - 类型转换 → 评估转换是否安全，记录转换方法行号
   - 集合操作 → 追踪参数是否进入集合后在循环中被使用

2. 若调用其他方法:
   - 读取被调用方法体
   - 追踪参数在被调用方法中的流向
   - 最多追踪 3 层调用链
   - 每层调用必须记录: 全限定类名.方法名(参数类型):行号

3. 参数消毒分析（对每个可控参数必须执行）:
   - 从 Source 到 Sink 路径上，扫描以下消毒操作:
     * 输入校验: @Valid, @Pattern, @Size, 自定义 Validator
     * 编码转义: HtmlUtils.htmlEscape, StringEscapeUtils, URLEncoder.encode
     * 白名单过滤: 枚举转换, switch-case 映射, Map.get 查找
     * 参数化查询: PreparedStatement, JPA Criteria, MyBatis #{}
     * 类型强转: Long.parseLong, Integer.valueOf (限制为数字类型)
   - 对发现的消毒操作评估:
     * 消毒是否完整（是否覆盖所有攻击向量）
     * 消毒是否可绕过（编码绕过、截断绕过、类型混淆）
     * 消毒后数据是否再次被拼接/修改
   - 输出格式:
     * 消毒方式: 具体方法名
     * 消毒位置: 全限定类名:行号
     * 消毒评估: 完整/不完整/可绕过 + 理由

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

### 检查点 6：配置文件关联分析

```
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

### 检查点 7：业务安全评估

```
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
   - 基于正向链路构造可复现的测试用例
   - 包含完整的请求路径和参数
```

### 检查点 8：生成审计报告

```
输出文件: output/phase4-api-audit.md

内容（按顺序）:
  1. 路由映射表（所有 P0+P1 端点 + 风险等级 + 业务用途）

  2. 每个端点的独立审计章节（必须包含以下结构）:

     ### POST /endpoint/path — CRITICAL (Score)
     
     **业务用途**: 一句话说明该 API 的业务功能（如 "云网关统一入口，转发各云服务商 API 调用"）
     **Controller**: 全限定类名 (文件名:行号)
     **认证**: 是/否
     **过滤**: 是/否
     **鉴权**: 是/否
     **关联配置**: 列出影响该 API 行为的配置项（配置键=配置值，文件名:行号）
     
     **参数分析**:
     
     | 参数 | 类型 | 业务含义 | Source 识别 | 校验方式 | 是否消毒 | Processing 链 | Sink | 结论 |
     |------|------|----------|------------|----------|----------|--------------|------|------|
     | name | @RequestParam String | 员工姓氏查询条件 | 用户可控 | 无 | 否 | 直接字符串拼接 | Statement.executeQuery | FAIL: SQL注入 |
     | vendor | @PathVariable String | 云服务商编码(如huawei/aliyun) | 用户可控 | 正则[A-Za-z\-]+ | 部分(仅字母和连字符) | 传递到Service层HTTP调用 | RestTemplate.exchange | WARN: SSRF风险 |
     
     **参数消毒分析**:
     
     | 参数 | 消毒方式 | 消毒位置 | 消毒评估 | 理由 |
     |------|----------|----------|----------|------|
     | name | 无 | - | 未消毒 | 从 Source 到 Sink 无任何净化操作 |
     | vendor | 正则校验 [A-Za-z\-]+ | GatewayController.java:42 | 部分有效 | 限制了特殊字符但仍允许构造有效路径 |
     
     **正向链路**:
     
     Step 1: 用户输入进入方法
       位置: org.owasp.webgoat.lessons.xxx.Controller.java:43
       代码: public AttackResult completed(@RequestParam String name, @RequestParam String auth_tan)
       说明: name 和 auth_tan 来自 HTTP 请求参数，用户完全可控 【Source】
       
     Step 2: 参数直接传递到内部方法
       位置: org.owasp.webgoat.lessons.xxx.Controller.java:44
       代码: return injectableQueryConfidentiality(name, auth_tan);
       说明: 参数未经任何校验或净化，直接传递 【无净化】
       
     Step 3: 字符串拼接构建 SQL 查询
       位置: org.owasp.webgoat.lessons.xxx.Controller.java:49-54
       代码: "SELECT * FROM employees WHERE last_name = '" + name + "' AND auth_tan = '" + auth_tan + "'"
       说明: 用户输入直接拼接到 SQL 语句，无 PreparedStatement 【危险】
       
     Step 4: 执行 SQL 查询
       位置: org.owasp.webgoat.lessons.xxx.Controller.java:62
       代码: ResultSet results = statement.executeQuery(query);
       说明: 拼接后的 SQL 直接执行，攻击者可注入任意 SQL 【Sink】
     
     **完整 Sink 路径**:
       org.owasp.webgoat.lessons.xxx.Controller.java:43 → org.owasp.webgoat.lessons.xxx.Controller.injectableQueryConfidentiality():44 → org.owasp.webgoat.lessons.xxx.Controller.java:62
       问题: org.owasp.webgoat.lessons.xxx.Controller.java 的 injectableQueryConfidentiality 方法，第 62 行，存在 SQL 注入漏洞
       
     **业务影响**: 员工数据查询接口，攻击者可获取所有员工信息（含信用卡号、认证令牌）
     
     **配置文件关联**:
       - 无关联配置 / 或列出关联配置及影响
     
     **PoC**: `name=' UNION SELECT userid, user_name, password, cookie, null, null, null FROM user_system_data --`

   3. 漏洞汇总清单（一行一条）:
      # | 类型 | 严重度 | 端点 | 完整 Sink 路径 | PoC

   4. 配置文件风险关联表:
      配置键 | 配置值 | 关联API | 风险影响

   5. 业务安全评估表
   6. 修复建议

禁止:
  - 不得遗漏审计队列中的任何 P0 或 P1 端点
  - 不得合并多个端点到一个章节
  - 不得包含评分公式或因子定义
  - 不得省略类全路径和行号
  - 不得省略步骤说明
  - 参数表不得省略"业务含义"和"是否消毒"列
  - 不得省略"完整 Sink 路径"段落
  - 不得省略"配置文件关联"段落
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
| 参数分析表 | 含业务含义、校验方式、是否消毒列 | ✅ |
| 参数消毒分析表 | 消毒方式、位置、评估、理由 | ✅ |
| 正向链路 | Step 1~N 完整 Source→Sink | ✅ |
| 完整 Sink 路径 | 全路径 A.java:行号 → B.java:行号 → C.java:行号 | ✅ |
| 业务影响 | 关联业务场景的影响描述 | ✅ |
| 配置文件关联 | 关联的配置项及影响说明 | ✅ |
| PoC | 可复现的测试用例 | ✅ |

## 常见错误

| 错误场景 | 正确做法 |
|----------|----------|
| 从 Statement.executeQuery 反推用户输入 | 必须从 @RequestParam 开始正向追踪 |
| 报告"存在 SQL 注入"但不说明业务影响 | 必须关联业务场景（如"用户查询接口可拖库"） |
| 忽略参数校验直接标记漏洞 | 先评估 @Valid/@Pattern 是否有效 |
| 追踪超过 3 层调用链 | 最多 3 层，超出则标记"需进一步追踪" |
| 脱离框架层风险孤立审计 API | 必须参考 phase2/phase3 的已知风险进行加权 |
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

## 参考

- 决策引擎规则详见 `references/decision-engine.md`
- 审计分支文件详见 `references/branch-*.md`
