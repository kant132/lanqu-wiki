---
name: java-security-audit
description: Load when user mentions Java security audit, web vulnerability assessment, Filter/Interceptor analysis, API route mapping, SQL injection, XSS, XXE, SSRF, path traversal, insecure deserialization, JWT vulnerability, or CSRF analysis for Java/Spring Boot web applications
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
---

# Java 正向安全审计

## 核心规则

1. **正向审计**：始终 Source → Processing → Sink，禁止从 Sink 反推 Source
2. **分层独立**：框架分析（Part 1）与 API 分析（Part 2）相互独立，不混入彼此逻辑
3. **输出统一**：所有中间输出和最终报告必须是 Markdown 文件，存放在 `output/` 目录
4. **断言即契约**：每个阶段必须评估所有强制断言，未评估则快速失败
5. **信息不足时询问**：当项目无 pom.xml/build.gradle 时，先询问用户，不得自行假设

## 工作流程

### 检查点 1：项目初始化与配置文件分析

```
Task: java-recon skill
输入: 项目根路径
输出: output/phase1-recon.md（含资产台账 + 配置文件深度分析 Config_Analysis）
验证: 
  - 资产台账非空 → 进入检查点 2；否则 ERR-EMPTY-INVENTORY 终止
  - Config_Analysis 非空 → 配置文件风险项传递到后续检查点
  - 若存在 application.yml/properties → 必须完成配置文件分析（C6 断言）
```

### 检查点 2：框架层审计（Phase 2 + Phase 3）

```
条件:
  - filters > 0 OR security_configs > 0 OR filter_registrations > 0
    → Task: java-filter-audit → output/phase2-filter-audit.md
  - interceptors > 0 → Task: java-interceptor-audit → output/phase3-interceptor-audit.md
  - 以上均为 0 → 生成空报告标记 WARN-NO-GUARD，进入检查点 3

必须执行:
  - Filter 执行顺序分析：提取所有 Filter 的执行链（order 值、URL 模式、Dispatcher 类型）
  - Interceptor 执行顺序分析：提取所有 Interceptor 的执行链（order 值、路径模式）
  - Filter 与 Interceptor 交叉关系：Filter 始终在 Interceptor 之前执行
  - Filter 注册配置审计：FilterRegistrationBean / @WebFilter / web.xml 注册方式
  - SecurityFilterChain 配置审计：CSRF、认证路径、密码编码器、CORS、会话管理等

验证: 审计资产数 ≤ Phase 1 发现数 → 进入检查点 3
```

### 检查点 3：汇总框架层 + 可达性评估

```
输入: output/phase1-recon.md + phase2-filter-audit.md + phase3-interceptor-audit.md
处理:
  1. 提取 FAIL 断言作为框架层已知风险
  2. 对每个 FAIL 断言执行可达性评估：
     - 前置拦截分析：该组件之前的 Filter/Interceptor 是否已拦截相同请求
     - 后置补偿分析：该组件之后的 Filter/Interceptor 是否能补偿该漏洞
     - Spring Security 层补偿：SecurityFilterChain 是否已限制该路径
     - 配置层补偿：CORS、会话管理等配置是否限制了攻击面
  3. 根据可达性调整严重度：
     - REACHABLE: 保持原严重度
     - PARTIALLY_REACHABLE: 严重度降一级
     - UNREACHABLE: 严重度降为 INFO（提示级别）
  4. 写入 output/final-audit-report.md 框架分析章节，标注可达性和调整后严重度
```

### 检查点 3.5：启动时安全配置审计

```
输入: 项目根路径 + output/phase1-recon.md
输出: output/phase2b-startup-config-audit.md

扫描目标：
  - @Configuration 类中定义的 @Bean 安全组件
  - @PostConstruct / ApplicationRunner / CommandLineRunner 中的安全初始化逻辑
  - ApplicationListener<ApplicationReadyEvent> 等启动事件监听器
  - @Import / @ImportResource 引入的安全配置
  - Spring Boot Auto-configuration 的覆盖/排除

审计维度（BC1-BC8）：

| 指针 | 检查项 | 说明 |
|------|--------|------|
| BC1 | 认证 Provider 配置 | 自定义 AuthenticationProvider / UserDetailsService 的实现是否安全？密码比对是否使用安全方式？ |
| BC2 | Token/JWT 配置 | JWT 签名算法、密钥来源、Token 过期策略是否安全？是否使用对称密钥且密钥硬编码？ |
| BC3 | 数据源安全初始化 | 数据库初始化脚本（schema.sql / data.sql / Flyway / Liquibase）是否包含硬编码密码或默认管理员账户？ |
| BC4 | 缓存安全配置 | Redis/Caffeine/Ehcache 配置是否有认证？缓存键是否包含敏感数据？ |
| BC5 | 消息队列安全 | RabbitMQ/Kafka 连接配置是否有认证？消息序列化是否安全？ |
| BC6 | 第三方服务集成 | 外部 API 调用的密钥/Token 管理方式？是否硬编码在 @Value 或 @Bean 中？ |
| BC7 | 定时任务安全 | @Scheduled 任务是否有权限控制？是否可被外部触发？ |
| BC8 | 自定义安全初始化 | @PostConstruct / ApplicationRunner 中是否有安全相关的初始化逻辑（如默认用户创建、权限初始化）？ |

输出要求：
  - 每个 @Bean 安全组件记录：Bean 名称、类型、所在类:行号、安全评估
  - 每个启动初始化逻辑记录：执行时机、安全影响、风险评估
  - 与 Phase 1 配置文件分析交叉验证（配置值是否与 Bean 定义一致）
```

### 检查点 4：API 发现与风险评估

```
Task: java-api-discovery skill
输入: output/phase1-recon.md（含 Config_Analysis） + 项目根路径
输出:
  - output/api-inventory.md（全量 API 路由清单 + 业务上下文）
  - output/api-risk-assessment.md（三维风险评分 + 业务用途 + 参数业务语义 + 配置文件关联 + 审计优先级）

验证:
  - 每个端点必须有业务用途说明
  - 每个参数必须有业务含义
  - 若存在配置文件风险项，必须关联到受影响的 API
```

### 检查点 4.5：威胁建模（API 审计前置）

```
输入: output/phase1-recon.md + output/phase2-filter-audit.md + output/phase3-interceptor-audit.md + output/api-risk-assessment.md
输出: output/threat-model.md

执行 STRIDE 威胁建模:
  1. 攻击面枚举: 未认证端点、认证后端点、数据层、集成层
  2. STRIDE 威胁识别: Spoofing/Tampering/Repudiation/InfoDisclosure/DoS/EoP
  3. 攻击树构建: 对 Top 3 高价值目标构建攻击路径
  4. 审计优先级调整: 基于攻击树补充/调整三维评分队列

确定性标注:
  - 攻击面枚举: DETERMINISTIC
  - STRIDE 威胁识别: HEURISTIC
  - 攻击树构建: SUBJECTIVE（需人工审核）
  - 优先级调整: SUBJECTIVE（需人工审核）

验证: 攻击树至少覆盖 3 个高价值目标 → 进入检查点 5
```

### 检查点 5：API 正向污点审计

```
Task: java-api-audit skill
输入:
  - output/threat-model.md（威胁建模 + 攻击树 + 调整后的审计优先级）
  - output/api-risk-assessment.md（来自检查点 4，含业务上下文 + 配置文件关联）
  - output/phase1-recon.md（含 Config_Analysis 配置文件分析）
  - output/phase2-filter-audit.md（三层审计 + 执行顺序 + 可达性评估）
  - output/phase2b-startup-config-audit.md（启动时安全配置审计）
  - output/phase3-interceptor-audit.md（框架层已知风险）
输出: output/phase4-api-audit.md
原则:
  - 每个端点独立章节，必须包含业务用途说明
  - 每个漏洞包含完整正向链路 Source → Processing → Sink（每步含文件全路径+行号+确定性标注）
  - 每个参数必须分析消毒/净化情况（结合 Sink 类型评估消毒有效性）
  - 必须包含完整 Sink 路径（Source文件:行号 → 中间方法:行号 → Sink文件:行号）
  - 必须关联配置文件分析结果
  - 必须包含可执行 curl PoC + 验证标准
  - 必须输出整体置信度（CONFIRMED/LIKELY/POSSIBLE）+ 依据
  - 必须执行跨请求污点追踪（存储型 XSS/二阶注入/Session 污染）
  - 必须执行业务逻辑漏洞审计（竞态/状态机/价格篡改/工作流绕过）
  - 必须生成 Fuzzing 字典
```

### 检查点 6：生成最终报告

```
输入: output/ 目录下所有阶段报告
输出: output/final-audit-report.md
结构: 详见 references/final-summary-output.md
```

### 检查点 7：综合安全分析（业务 + 技术 + 配置）

```
输入: output/ 目录下所有阶段报告
输出: output/comprehensive-security-analysis.md

生成三维综合分析，将业务、技术、配置三个维度的安全发现关联起来：

## 7.1 业务安全分析

从业务视角审视所有发现：
  - 核心业务流程的安全风险（交易、支付、权限变更等关键操作）
  - 数据资产敏感度分级（用户隐私、财务数据、认证凭证、业务配置）
  - 业务逻辑漏洞（越权访问、业务绕过、数据篡改）
  - 多租户/多项目隔离风险
  - 第三方服务集成的业务影响

输出格式：
  | 业务场景 | 关联API | 风险类型 | 严重度 | 业务影响 |
  |----------|---------|----------|--------|----------|

## 7.2 技术安全分析

从技术实现视角汇总所有代码级漏洞：
  - 按漏洞类型分组（SQL注入、XSS、XXE、SSRF、反序列化等）
  - 统计每种类型的数量、严重度分布
  - 识别共性缺陷模式（如"所有 SQL 查询均使用字符串拼接"）
  - 评估技术债务的系统性风险

输出格式：
  | 漏洞类型 | 数量 | 最高严重度 | 共性模式 | 系统性风险 |
  |----------|------|-----------|----------|-----------|

## 7.3 配置安全分析

从配置视角汇总所有配置相关风险：
  - application.yml/properties 风险配置项
  - SecurityFilterChain 配置缺陷
  - @Bean 安全组件配置问题
  - 启动时安全初始化问题
  - 环境差异风险（dev/prod profile 配置差异）

输出格式：
  | 配置类别 | 配置项 | 当前值 | 风险等级 | 建议值 | 影响范围 |
  |----------|--------|--------|----------|--------|----------|

## 7.4 交叉关联分析

将三个维度的发现进行交叉关联，识别复合风险：

1. 配置 + 技术 复合风险：
   - 配置缺陷放大了技术漏洞的影响
   - 例如：CSRF 禁用 + 状态变更 API 无 Token 校验 = CSRF 攻击可达

2. 业务 + 技术 复合风险：
   - 技术漏洞对核心业务的影响程度
   - 例如：SQL 注入 + 用户认证表 = 全量用户数据泄露

3. 业务 + 配置 复合风险：
   - 配置不当对业务逻辑的影响
   - 例如：Actuator 暴露 + 数据库连接池配置 = 数据库凭证泄露

4. 三维复合风险：
   - 同时涉及业务、技术、配置的严重风险链
   - 例如：密码明文存储(配置) + 无角色控制(技术) + 管理员账户(业务) = 完全接管

输出格式：
  | # | 复合风险描述 | 涉及维度 | 关联发现 | 综合严重度 | 攻击链 |
  |---|-------------|----------|----------|-----------|--------|

## 7.5 攻击面总览

绘制完整攻击面：
  - 外部攻击面：未认证可达的 API 端点
  - 内部攻击面：认证后可利用的漏洞
  - 配置攻击面：通过配置泄露/篡改可利用的风险
  - 供应链攻击面：已知 CVE 依赖

输出格式：
  | 攻击面类型 | 入口点数量 | 最高风险 | 关键发现 |
  |-----------|-----------|----------|----------|
```

## 常见错误

| 错误场景 | 正确做法 |
|----------|----------|
| 项目无自定义 Filter，直接跳过 Phase 2 | 必须审计 SecurityFilterChain 配置（CSRF、permitAll、密码编码器） |
| 从 SQL 执行语句反推用户输入 | 必须从 @RequestParam/@RequestBody 开始正向追踪 |
| 框架层风险混入 API 章节 | 框架分析结果写入 final-audit-report.md 的"框架分析结果"章节，API 漏洞写入"API 分析结果"章节 |
| 输出 JSON 或纯文本报告 | 所有输出必须是 Markdown 文件 |
| 忽略 application.yml/properties 配置文件 | 必须执行 C6 断言，深度分析配置文件安全相关项 |
| API 风险评估不写业务用途 | 每个端点必须有业务用途说明，每个参数必须有业务含义 |
| 不分析参数消毒情况 | 每个可控参数必须分析从 Source 到 Sink 是否有消毒操作 |
| Sink 路径不完整 | 必须输出完整 Source→Sink 路径，每步含文件全路径+行号 |
| 不关联配置文件分析 | API 审计必须结合 Config_Analysis 分析配置对安全的影响 |
| 不分析 Filter/Interceptor 执行顺序 | 必须提取执行链顺序，分析前置拦截和后置补偿关系 |
| 框架层漏洞不评估可达性 | 每个 FAIL 断言必须评估可达性（REACHABLE/PARTIALLY_REACHABLE/UNREACHABLE） |
| 被前置 Filter 拦截的漏洞仍标记为高危 | UNREACHABLE 的漏洞必须降为 INFO（提示级别） |
| 只审计 Filter 类代码，不审计 Filter 注册配置 | 必须同时审计 FilterRegistrationBean / @WebFilter / web.xml 注册配置（FC1-FC6） |
| 只审计 SecurityFilterChain 的 csrf/permitAll | 必须完整审计 SC1-SC10 所有配置维度 |
| 忽略启动时安全配置 | 必须审计 @Configuration @Bean、@PostConstruct、ApplicationRunner 等启动时安全初始化逻辑 |
| 最终报告不做综合分析 | 必须生成业务+技术+配置三维综合分析，含交叉关联和攻击面总览 |
| 不做威胁建模直接审计 API | 必须在 API 审计前执行 STRIDE 威胁建模，生成攻击树指导审计优先级 |
| PoC 只写 payload 片段 | 必须为可执行 curl 命令，含认证步骤+攻击请求+预期响应特征+验证标准 |
| 不标注确定性等级 | 每个审计步骤必须标注 DETERMINISTIC/HEURISTIC/SUBJECTIVE，每个漏洞必须输出置信度 |
| 脱离 Sink 类型判断消毒有效性 | 必须查 taint-semantics.md 矩阵，htmlEscape 对 SQL 无效 |
| 忽略跨请求污点追踪 | 存储型 XSS/二阶注入/Session 污染必须追踪 DB/Session/缓存的跨请求流向 |
| 忽略业务逻辑漏洞 | 必须对业务操作类端点执行竞态/状态机/价格篡改/工作流绕过检查 |

## 输出文件

| 阶段 | 文件 |
|------|------|
| Phase 1 | `output/phase1-recon.md` |
| Phase 2 | `output/phase2-filter-audit.md` |
| Phase 2b | `output/phase2b-startup-config-audit.md` |
| Phase 3 | `output/phase3-interceptor-audit.md` |
| API 发现 | `output/api-inventory.md` |
| API 风险评估 | `output/api-risk-assessment.md` |
| 威胁建模 | `output/threat-model.md` |
| API 审计 | `output/phase4-api-audit.md` |
| 最终报告 | `output/final-audit-report.md` |
| 综合分析 | `output/comprehensive-security-analysis.md` |

## 参考

- 断言状态/数据协议/错误码见 `references/shared-contracts.md`
- 最终报告结构见 `references/final-summary-output.md`
- 各 Phase 子 Skill 断言定义见对应子 Skill
