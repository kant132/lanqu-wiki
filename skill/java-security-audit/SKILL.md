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

### 检查点 1：项目初始化

```
Task: java-recon skill
输入: 项目根路径
输出: output/phase1-recon.md
验证: 资产台账非空 → 进入检查点 2；否则 ERR-EMPTY-INVENTORY 终止
```

### 检查点 2：框架层审计（Phase 2 + Phase 3）

```
条件:
  - filters > 0 OR security_configs > 0 → Task: java-filter-audit → output/phase2-filter-audit.md
  - interceptors > 0 → Task: java-interceptor-audit → output/phase3-interceptor-audit.md
  - 三者均为 0 → 生成空报告标记 WARN-NO-GUARD，进入检查点 3

验证: 审计资产数 ≤ Phase 1 发现数 → 进入检查点 3
```

### 检查点 3：汇总框架层

```
输入: output/phase1-recon.md + phase2-filter-audit.md + phase3-interceptor-audit.md
处理: 提取 FAIL 断言作为框架层已知风险，写入 output/final-audit-report.md 框架分析章节
```

### 检查点 4：API 发现与风险评估

```
Task: java-api-discovery skill
输入: output/phase1-recon.md + 项目根路径
输出:
  - output/api-inventory.md（全量 API 路由清单）
  - output/api-risk-assessment.md（三维风险评分 + 审计优先级）
```

### 检查点 5：API 正向污点审计

```
Task: java-api-audit skill
输入:
  - output/api-risk-assessment.md（来自检查点 4）
  - output/phase2-filter-audit.md（框架层已知风险）
  - output/phase3-interceptor-audit.md（框架层已知风险）
输出: output/phase4-api-audit.md
原则: 每个端点独立章节，每个漏洞包含完整正向链路 Source → Processing → Sink + PoC + 业务影响
```

### 检查点 6：生成最终报告

```
输入: output/ 目录下所有阶段报告
输出: output/final-audit-report.md
结构: 详见 references/final-summary-output.md
```

## 常见错误

| 错误场景 | 正确做法 |
|----------|----------|
| 项目无自定义 Filter，直接跳过 Phase 2 | 必须审计 SecurityFilterChain 配置（CSRF、permitAll、密码编码器） |
| 从 SQL 执行语句反推用户输入 | 必须从 @RequestParam/@RequestBody 开始正向追踪 |
| 框架层风险混入 API 章节 | 框架分析结果写入 final-audit-report.md 的"框架分析结果"章节，API 漏洞写入"API 分析结果"章节 |
| 输出 JSON 或纯文本报告 | 所有输出必须是 Markdown 文件 |

## 输出文件

| 阶段 | 文件 |
|------|------|
| Phase 1 | `output/phase1-recon.md` |
| Phase 2 | `output/phase2-filter-audit.md` |
| Phase 3 | `output/phase3-interceptor-audit.md` |
| API 发现 | `output/api-inventory.md` |
| API 风险评估 | `output/api-risk-assessment.md` |
| API 审计 | `output/phase4-api-audit.md` |
| 最终报告 | `output/final-audit-report.md` |

## 参考

- 断言状态/数据协议/错误码见 `references/shared-contracts.md`
- 最终报告结构见 `references/final-summary-output.md`
- 各 Phase 子 Skill 断言定义见对应子 Skill
