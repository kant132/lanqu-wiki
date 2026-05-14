# Code Audit Skill - 智能代码审计技能

> 专业白盒代码安全审计技能，支持 55+ 漏洞类型，双轨审计模型，多 Agent 深度分析。

![Code Audit Banner](https://img.shields.io/badge/Code%20Audit-Skill-blue)
![Languages](https://img.shields.io/badge/Languages-9-orange)
![Frameworks](https://img.shields.io/badge/Frameworks-14-green)
![Vulnerabilities](https://img.shields.io/badge/Vulnerabilities-55+-red)

---

## 目录

1. [概述](#概述)
2. [核心能力](#核心能力)
3. [安装与使用](#安装与使用)
4. [架构设计](#架构设计)
5. [双轨审计模型](#双轨审计模型)
6. [10 个安全维度](#10-个安全维度)
7. [多 Agent 工作流](#多-agent-工作流)
8. [污点分析](#污点分析)
9. [防幻觉规则](#防幻觉规则)
10. [支持的技术栈](#支持的技术栈)
11. [文件结构](#文件结构)

---

## 概述

Code Audit 是为 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 设计的专业安全审计技能。采用白盒静态分析方法论，系统性发现和验证源代码中的安全漏洞。

### 特性亮点

- **9 种语言**: Java, Python, Go, PHP, JavaScript/Node.js, C/C++, .NET/C#, Ruby, Rust
- **14 种框架**: Spring Boot, Django, Flask, FastAPI, Express, Koa, Gin, Laravel, Rails, ASP.NET Core, Rust Web, NestJS/Fastify, MyBatis
- **55+ 漏洞类型**: SQL 注入、RCE、反序列化、SSRF、SSTI、XXE、IDOR、竞态条件、业务逻辑缺陷等
- **143 项强制检测**: 按 10 个安全维度 (D1-D10) 组织的语言级检查清单
- **双轨审计模型**: Sink-driven（注入/RCE）+ Control-driven（授权/业务逻辑）
- **多 Agent 并行**: 大型代码库并行审计（874+ Java 文件约 15 分钟）
- **攻击链构建**: 自动将多个发现串联为可利用的攻击路径

---

## 核心能力

### 扫描模式

| 模式 | 适用场景 | 范围 |
|------|---------|------|
| **Quick** | CI/CD、小项目 | 高危漏洞、敏感信息、依赖 CVE |
| **Standard** | 常规审计 | OWASP Top 10、认证授权、加密，1-2 轮 |
| **Deep** | 重要项目、渗透测试 | 全覆盖、攻击链、业务逻辑，2-3 轮 |
| **Quick-Diff** | PR Review、增量审计 | 仅 git diff 变更文件 |

### 触发方式

```
"审计这个项目"
"检查代码安全"
"找出安全漏洞"
"/audit" 或 "/code-audit"
```

### 使用示例

```
用户: /code-audit deep /path/to/project

Claude: [MODE] deep
        [RECON] 874 文件, Spring Boot 1.5 + Shiro 1.6 + JPA + Freemarker
        [PLAN] 5 个 Agent, D1-D10 覆盖, 预估 125 turns
        ... (用户确认) ...
        [REPORT] 10 Critical, 14 High, 12 Medium, 4 Low
```

---

## 安装与使用

### 安装

```bash
# 克隆到 Claude Code skills 目录
cp -r code-audit ~/.claude/skills/

# 或从仓库克隆
cd ~/.claude/skills
git clone <repository-url> code-audit
```

在 Claude Code 中请求安全审计时，技能自动激活。

---

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Code Audit Skill                              │
│                                                                 │
│  Phase 1: 侦察                                                  │
│    → 技术栈识别                                                 │
│    → 攻击面映射（五层推导）                                      │
│    → 端点-权限矩阵生成                                          │
│    → Agent 分配                                                 │
│                                                                 │
│  Phase 2: 并行 Agent 执行                                       │
│    → Agent 1: 注入 (D1) [sink-driven]                          │
│    → Agent 2: 认证+授权+业务逻辑 (D2+D3+D9) [control-driven]    │
│    → Agent 3: 文件+SSRF (D5+D6) [sink-driven]                  │
│    → Agent 4: 反序列化 (D4) [sink-driven]                       │
│    → Agent 5: 配置+加密+供应链 (D7+D8+D10) [config-driven]     │
│                                                                 │
│  Phase 3: 覆盖评估                                              │
│    → 按轨道计算覆盖率                                            │
│    → 缺口识别 → R2 补充                                          │
│                                                                 │
│  Phase 4: 报告生成                                              │
│    → 严重度校准                                                  │
│    → 去重合并                                                    │
│    → 攻击链构建                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 三轮审计模型

| 轮次 | 目标函数 | 方法 | 发现的漏洞类型 |
|------|---------|------|--------------|
| **R1** | max(覆盖面) | Grep 模式匹配 + 入口点识别 | 模式明显的漏洞（硬编码、未验证、配置缺陷） |
| **R2** | max(深度) | 逐行代码审计 + 数据流分析 | 需要追踪才能发现的漏洞（SQL 拼接链、协议注入） |
| **R3** | max(关联度) | 攻击链构建 + 交叉验证 | 单独看不危险、组合后高危的漏洞（IDOR+白名单） |

---

## 双轨审计模型

不同类型的漏洞需要根本不同的检测策略：

| 轨道 | 维度 | 方法 | 发现目标 |
|------|-----|------|---------|
| **Sink-driven** | D1（注入）、D4（反序列化）、D5（文件）、D6（SSRF） | Grep 危险函数 → 追踪数据流 → 验证无防护 | **存在的**危险代码 |
| **Control-driven** | D3（授权）、D9（业务逻辑） | 枚举端点 → 验证安全控制是否存在 → 缺失=漏洞 | **缺失的**安全控制 |
| **Config-driven** | D2（认证）、D7（加密）、D8（配置）、D10（供应链） | 搜索配置 → 对比安全基线 | 错误配置 |

### 核心区别

> **关键区别**: Sink-driven 搜索"存在的危险代码"，Control-driven 搜索"应存在但缺失的安全控制"。
> 授权缺失、IDOR 等漏洞本质上是**代码不存在**（没有权限检查），Grep 搜不到"不存在的代码"。

---

## 10 个安全维度

| # | 维度 | 覆盖内容 |
|---|------|---------|
| D1 | 注入 | SQL/Cmd/LDAP/SSTI/SpEL/JNDI |
| D2 | 认证 | Token/Session/JWT/Filter 链 |
| D3 | 授权 | CRUD 权限一致性、IDOR、水平越权 |
| D4 | 反序列化 | Java/Python/PHP Gadget 链 |
| D5 | 文件操作 | 上传/下载/路径遍历 |
| D6 | SSRF | URL 注入、协议限制 |
| D7 | 加密 | 密钥管理、加密模式、KDF |
| D8 | 配置 | Actuator、CORS、错误信息暴露 |
| D9 | 业务逻辑 | 竞态条件、Mass Assignment、状态机、多租户隔离 |
| D10 | 供应链 | 依赖 CVE、版本检查 |

### 项目类型 → 维度权重

| 项目类型 | 重点维度 | 审计焦点 |
|---------|---------|---------|
| 金融/支付 | D9(++), D1(++) | 竞态条件、金额篡改、注入 |
| 数据平台/BI | D1(++), D6(++) | SQL 引擎注入、SSRF、权限隔离 |
| 文件存储/CMS | D5(++), D3(+) | 文件操作、路径遍历、后台越权 |
| 身份认证平台 | D2(++), D3(++) | 认证链、授权、加密 |
| IoT/嵌入式 | D7(++), D2(++) | 加密、认证、固件 |

---

## 多 Agent 工作流

### Agent 切分原则

```
Agent 1: 注入 (D1) [sink-driven]
  — SQL/SpEL/LDAP/命令注入，追踪用户输入到Sink

Agent 2: 认证+授权+业务逻辑 (D2+D3+D9) [control-driven + config-driven]
  — ★ 此 Agent 使用 Control-driven 策略，输入 = Phase 1 端点-权限矩阵
  — D3: 遍历端点矩阵验证权限注解 → CRUD 权限一致性对比 → 认证豁免路径审计
  — D9: findById 归属校验 → Mass Assignment → 状态机 → 并发安全

Agent 3: 文件+SSRF (D5+D6) [sink-driven]
  — 上传下载/路径遍历/SSRF/JDBC URL

Agent 4: 反序列化+RCE (D4) [sink-driven]
  — Java反序列化/Fastjson/Jackson/SnakeYAML

Agent 5: 配置+加密+供应链 (D7+D8+D10) [config-driven]
  — 硬编码密钥/Actuator/依赖CVE
```

### Agent 合约要素

每个 Agent 必须包含以下合约字段：

| 字段 | 说明 |
|------|------|
| `[搜索路径]` | Phase 1 产出的核心代码目录列表 |
| `[排除目录]` | node_modules, .git, build, dist, target, test, frontend |
| `[审计策略]` | sink-driven / control-driven / config-driven |
| `[Turn 预留]` | max_turns - 3 时立即产出结构化输出 |
| `[输出格式]` | HEADER → 发现表格 → SENTINEL |

### 输出模板

```markdown
## Agent: {方向名称} | Round {N} | 发现: {数量}

=== HEADER START ===
COVERAGE: D1=✅(3,fan=5/12), D2=⚠️(1,fan=1/8), D3=❌, ...
UNCHECKED: D1:[orderBy injection]: ORDER BY ${param} | ...
UNFINISHED: {描述}|{原因: 超时/超预算/需下轮深入}, ...
STATS: tools={N}/50 | files_read={N} | grep_patterns={N} | ...
=== HEADER END ===

=== TRANSFER BLOCK START ===
FILES_READ: {file1}:{结论} | {file2}:{结论} | ...
GREP_DONE: {pattern1} | {pattern2} | ...
HOTSPOTS: {file:line:断点描述} | ...
=== TRANSFER BLOCK END ===

| # | 等级 | 漏洞标题 | 位置 | 关键证据 | 数据流 |
|---|------|---------|------|----------|--------|
| 1 | C | JWT无签名验证 | TokenUtils.java:14 | JWT.decode(token) 无 verify | HTTP→TokenFilter→JWT.decode |

=== AGENT_OUTPUT_END ===
```

---

## 污点分析

污点分析是代码审计的核心方法论，通过追踪不可信数据(污点)从进入系统到触发危险操作的完整流程。

### 污点分析流程

```
┌─────────────────────────────────────────────────────────────────┐
│                      Taint Analysis Flow                        │
│                                                                 │
│   Source ──→ Propagation ──→ Sanitizer? ──→ Sink               │
│   (污点源)    (传播路径)      (净化检查)     (汇聚点)            │
│                                                                 │
│   用户输入    变量赋值         过滤/转义      危险函数            │
│              函数参数          验证/编码      执行操作            │
│              返回值            白名单                            │
└─────────────────────────────────────────────────────────────────┘
```

### Slot 类型分类

不同的 sink 位置需要不同的防护措施：

| Slot Type | 代码特征 | 正确防护 | 无效防护 |
|-----------|----------|----------|----------|
| **SQL-val** | `WHERE col = ?` | 参数绑定 | - |
| **SQL-ident** | `ORDER BY ${col}` | **白名单** | 参数绑定无效! |
| **CMD-argument** | `cmd [arg1]` | shell=False + 数组传参 | 黑名单过滤 |
| **FILE-path** | 文件路径拼接 | resolve() + 边界检查 | `../` 黑名单 |

### 净化后拼接检测

> **关键规则**: 如果 concat 发生在 sanitization 之后，该净化措施可能无效

**危险模式**:

```python
# ❌ 危险: 部分参数净化
name = escape_sql(request.form['name'])           # sanitized
sort = request.form['sort']                       # NOT sanitized!
query = f"SELECT * FROM users WHERE name = '{name}' ORDER BY {sort}"  # 危险!
```

---

## 防幻觉规则

所有发现必须基于工具实际读取的代码：

| 规则 | 要求 |
|------|------|
| **文件验证** | 文件路径必须通过 Glob/Read 验证后才能报告 |
| **代码真实性** | 代码片段必须来自 Read 工具的实际输出 |
| **禁止猜测** | 禁止基于"典型项目结构"猜测 |
| **匹配技术栈** | 禁止报告项目中不存在的技术栈漏洞 |

### 核心原则

> **宁可漏报，不可误报。质量优于数量。**

```
正确示例:
1. 查询 auth_bypass 知识 → 了解认证绕过的概念
2. 使用 Read 工具读取项目的认证代码
3. 只有**实际看到**有问题的代码才报告漏洞
4. file_path 必须是你**实际读取过**的文件
```

---

## 支持的技术栈

### 语言

| 语言 | 模块路径 |
|------|---------|
| Java | `references/languages/java.md` |
| Python | `references/languages/python.md` |
| Go | `references/languages/go.md` |
| PHP | `references/languages/php.md` |
| JavaScript | `references/languages/javascript.md` |
| C/C++ | `references/languages/c_cpp.md` |
| .NET/C# | `references/languages/dotnet.md` |
| Ruby | `references/languages/ruby.md` |
| Rust | `references/languages/rust.md` |

### 框架

| 框架 | 模块路径 |
|------|---------|
| Spring Boot | `references/frameworks/spring.md` |
| Django | `references/frameworks/django.md` |
| Flask | `references/frameworks/flask.md` |
| FastAPI | `references/frameworks/fastapi.md` |
| Express | `references/frameworks/express.md` |
| Gin | `references/frameworks/gin.md` |
| Laravel | `references/frameworks/laravel.md` |
| Rails | `references/frameworks/rails.md` |
| NestJS/Fastify | `references/frameworks/nest_fastify.md` |

### 安全专项

| 领域 | 模块路径 |
|------|---------|
| API 安全 | `references/security/api_security.md` |
| LLM/AI 安全 | `references/security/llm_security.md` |
| 密码学 | `references/security/cryptography.md` |
| OAuth/OIDC/SAML | `references/security/oauth_oidc_saml.md` |
| 竞态条件 | `references/security/race_conditions.md` |
| 供应链安全 | `references/security/infra_supply_chain.md` |

---

## 文件结构

```
code-audit/
├── SKILL.md                    # 技能入口（frontmatter + 执行控制器）
├── agent.md                    # Agent 工作流（状态机 + 双轨模型）
├── README.md                   # 文档（英文）
├── README_CN.md                # 文档（中文）
└── references/
    ├── core/              (16) # 核心方法论
    │   ├── phase2_deep_methodology.md   # 双轨审计方法论
    │   ├── taint_analysis.md            # 数据流追踪
    │   ├── comprehensive_audit_methodology.md  # 全面审计框架
    │   ├── anti_hallucination.md        # 防误报规则
    │   ├── sinks_sources.md             # Source/Sink 定义库
    │   ├── semantic_search_guide.md     # 语义搜索指南
    │   ├── poc_generation.md            # PoC 生成指南
    │   ├── verification_methodology.md   # 漏洞验证方法论
    │   └── ...
    ├── checklists/        (11) # D1-D10 覆盖矩阵 + 9 语言检查清单
    ├── languages/         (18) # 语言漏洞模式
    ├── security/          (21) # 安全域模块
    ├── frameworks/        (14) # 框架专项模块
    ├── adapters/           (5) # 语言适配器 (YAML)
    ├── wooyun/             (9) # WooYun 真实案例库
    ├── cases/              (1) # 真实漏洞案例
    └── reporting/          (1) # 报告模板
```

---

## 参考资源

### 核心文档

| 文档 | 说明 |
|------|------|
| [comprehensive_audit_methodology.md](references/core/comprehensive_audit_methodology.md) | 全面审计方法论 - 避免遗漏的系统性框架 |
| [phase2_deep_methodology.md](references/core/phase2_deep_methodology.md) | Phase 2 深度审计方法论 - 三轨执行策略 |
| [taint_analysis.md](references/core/taint_analysis.md) | 污点分析模块 - 数据流追踪核心 |
| [coverage_matrix.md](references/checklists/coverage_matrix.md) | 覆盖率矩阵 - D1-D10 审计追踪 |

### 相关文章

- [Code Audit Skill 详解（上）](https://mp.weixin.qq.com/s/K5yJ9nPUzwpBV5rMPPKfCg)
- [Code Audit Skill 详解（下）](https://mp.weixin.qq.com/s/yTPehTfk1ufv3RXq6gh1mA)

---

## 许可证

MIT License

## 免责声明

本技能仅用于**授权的安全测试**。使用者必须：
- 拥有审计目标代码的合法授权
- 负责任地披露发现的漏洞
- 遵守相关法律法规和道德规范

未经授权对他人系统进行安全测试可能违法。

---

*本文档由 Code Audit Skill 自动生成，基于 v2.5.0 版本*