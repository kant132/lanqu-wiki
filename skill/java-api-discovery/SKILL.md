---
name: java-api-discovery
description: Load when you need to extract all API routes from a Java/Spring Boot project, identify input parameters for each endpoint, and calculate 3D risk scores (validation × dangerous_param × business_impact). Use for API asset inventory, risk triage, or as input to java-api-audit
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Java API 发现与三维风险评估

## 核心规则

1. **全量提取**：必须输出所有端点，禁止使用 `...`、`以上为摘要`、`仅列出关键端点` 等省略语。若端点数 > 50，分多段输出
2. **三维评分**：Risk_Score = 参数校验因子 × 高危参数因子 × 业务意义因子（乘法模型）
3. **一票否决**：若参数校验发现强正则/白名单，直接标记 priority: LOW，score=1
4. **输出前校验**：写入文件前必须验证每个端点的 Score 与所在分区一致，不一致则重新计算
5. **输出纯净**：输出文件只含结果数据，不得包含评分公式、因子定义（这些在 references 中）
6. **输出统一**：所有输出为 Markdown 文件，存放在 `output/` 目录

## 工作流程

### 检查点 1：路由提取

```
输入: 项目根路径 + output/phase1-recon.md（引擎类型 + 配置文件分析）
输出: output/api-inventory.md

根据引擎类型执行对应提取算子:
  - Spring MVC: 扫描 @Controller/@RestController，拼接类级+方法级 @RequestMapping
  - JAX-RS: 扫描 @Path 资源类，识别 @GET/@POST/@PUT/@DELETE
  - Servlet: 解析 web.xml <servlet-mapping> + @WebServlet
  - RPC: 扫描 @DubboService/@DubboReference/gRPC ImplBase

每个端点必须提取:
  - HTTP 方法 + 完整路径（含类级前缀）
  - 所有输入参数（@RequestParam/@RequestBody/@PathVariable/@RequestHeader/@CookieValue）
  - 参数类型、是否必填、默认值
  - Controller 类全限定名 + 方法名 + 行号

强制要求:
  - 输出文件中不得出现 "..."、"以上为摘要"、"仅列出" 等省略语
  - 必须逐行输出每一个端点，即使超过 100 个
```

### 检查点 1.5：业务上下文提取

```
输入: 项目根路径 + output/api-inventory.md
输出: 更新 output/api-inventory.md（追加业务上下文字段）

对每个端点必须提取以下业务上下文:

1. API 业务用途说明:
   - 从 Controller 类名/方法名/注释/Swagger 注解（@ApiOperation/@Operation）推断业务含义
   - 从 Service 层方法名推断业务操作类型（查询/创建/更新/删除/审批/导出等）
   - 若存在 API 文档（Swagger/OpenAPI），提取 summary/description
   - 输出格式: 一句话描述该 API 的业务用途

2. 参数业务语义:
   - 对每个输入参数，说明其业务含义（不是技术类型）
   - 例如: project_id → "云服务项目ID，标识用户所属项目"
   - 例如: vendor → "云服务商编码，如 huawei/aliyun/aws"
   - 从参数命名、注释、DTO 字段注解推断业务含义

3. 参数使用方式:
   - 参数在业务逻辑中如何使用（查询条件/路径拼接/权限判断/业务计算等）
   - 参数是否传递到 Service 层、DAO 层
   - 参数是否参与外部调用（HTTP/RPC/MQ）

4. 配置文件关联:
   - 检查 output/phase1-recon.md 中的 Config_Analysis
   - 识别哪些 API 的行为受配置文件控制
   - 例如: 文件上传 API 受 spring.servlet.multipart.max-file-size 控制
   - 例如: 网关 API 的超时/重试受自定义配置控制
   - 输出格式: 关联的配置键 + 配置值 + 对 API 行为的影响

强制要求:
  - 每个端点必须有业务用途说明，不得为空
  - 每个参数必须有业务语义说明，不得仅写技术类型
  - 若存在配置文件关联，必须标注
```

### 检查点 2：三维风险评分

```
输入: output/api-inventory.md（含业务上下文）
输出: output/api-risk-assessment.md

对每个端点计算三维风险评分:
  - 参数校验因子: LOW=1 / MEDIUM=3 / HIGH=5
  - 高危参数因子: LOW=1 / MEDIUM=3 / HIGH=5
  - 业务意义因子: LOW=1 / MEDIUM=3 / HIGH=5
  - Risk_Score = 参数校验因子 × 高危参数因子 × 业务意义因子

业务意义因子评估增强:
  - 必须结合业务上下文评估，不得仅根据 URL 路径猜测
  - 参考 API 业务用途说明、Service 层操作类型、数据敏感度
  - 参考配置文件关联：若 API 行为受配置控制且配置存在风险，业务意义因子上调一级

一票否决:
   若参数校验因子 = LOW（强校验），直接 score=1，priority=LOW

风险等级:
   CRITICAL ≥ 60 → 必须审计
   HIGH 15-59 → 必须审计
   MEDIUM 3-14 → 选择性审计
   LOW ≤ 2 → 强制熔断

输出前校验:
   对每个端点验证: Score 必须与所在分区一致
   例如: Score=45 不得出现在 CRITICAL 分区，Score=75 不得出现在 HIGH 分区
   若不一致，重新计算因子后修正
```

### 检查点 3：输出 API 清单

```
输出文件: output/api-risk-assessment.md

内容要求（按顺序）:
  1. CRITICAL 端点列表（Score ≥ 60，逐行输出，不得省略）
     每个端点必须包含:
     - 端点 ID + HTTP 方法 + 完整路径
     - 业务用途说明（一句话）
     - 三维评分明细 + 评分理由
     - 输入参数表（参数名 | 类型 | 业务含义 | 校验方式 | 是否消毒 | 风险描述）
     - 配置文件关联（若有）

  2. HIGH 端点列表（Score 15-59，逐行输出，不得省略）
     格式同 CRITICAL

  3. MEDIUM 端点列表（Score 3-14，逐行输出，不得省略）
     格式同 CRITICAL

  4. LOW 端点列表（Score ≤ 2，可合并为一行统计）

  5. 审计优先级排序表（P0=CRITICAL, P1=HIGH, P2=MEDIUM）
     列: 优先级 | 端点ID | 路径 | 业务用途 | Score | 审计建议

  6. 进入 java-api-audit 的端点清单（P0 + P1 全量列出）
     列: # | 端点ID | 完整路径 | HTTP方法 | 业务用途 | Score

  7. 配置文件风险关联汇总
     列: 配置键 | 配置值 | 风险等级 | 关联API | 影响说明

禁止:
  - 不得包含评分公式（公式在 references/risk-modeling.md）
  - 不得包含因子定义表（定义在 references/risk-modeling.md）
  - 不得使用 "..." 或 "以上为摘要"
  - 不得遗漏业务用途说明
  - 参数表不得仅写技术类型，必须包含业务含义
```

## 常见错误

| 错误场景 | 正确做法 |
|----------|----------|
| 只扫描 @RestController，遗漏 @Controller | 两者都必须扫描 |
| 忽略类级 @RequestMapping 前缀 | 必须拼接类级+方法级路径 |
| 遗漏 @RequestHeader/@CookieValue 参数 | 所有输入注解都必须提取 |
| 使用加法计算风险评分 | 必须使用乘法模型 |
| 对强校验端点仍进行深度审计 | 一票否决，直接标记 LOW |
| 使用 "..." 或 "以上为摘要" 省略端点 | 必须逐行输出所有端点 |
| Score 与分区不一致 | 输出前校验，不一致则重新计算 |
| 输出文件中包含评分公式 | 公式在 references 中，输出只含结果 |
| 参数只写技术类型（如 "String"），不写业务含义 | 每个参数必须说明业务语义（如 "云服务商编码"） |
| API 不写业务用途说明 | 每个端点必须有一句话业务用途描述 |
| 忽略配置文件对 API 行为的影响 | 必须关联 phase1-recon.md 中的 Config_Analysis |
| 不分析参数是否经过消毒/净化 | 参数表必须包含"是否消毒"列 |

## 参考

- 路由提取算子详见 `references/route-extraction.md`
- 三维风险建模详见 `references/risk-modeling.md`
