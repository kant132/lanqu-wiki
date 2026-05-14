# Agent Skill 写作完全指南：步骤 · 技巧 · 规范 · 注意事项

> 综合 Anthropic 官方 skill-creator、Google ADK、OpenAI Eval、Perplexity 实践及 Claude Code 逆向工程


## 一、Skill 本质认知

**Skill 是什么**：不是 Prompt，是「程序性知识的载体」——让 Agent 在真实工作环境中可执行、可复用、可验证的专业能力模块。

**三种税制（Perplexity 提出）**：
- **索引税**：每个会话对所有可见 Skill 的 name+description 做一次加载（~100 tokens）
- **加载税**：SKILL.md 被完整加载时的 Token 消耗
- **运行时税**：Agent 主动读取 references/scripts 的成本

> 核心原则：越靠近上下文入口，税率越高。没有这条指令 Agent 会犯错吗？通不过，删掉。


## 二、Skill 写作六步法

### Step 1：判定「是否值得写成 Skill」

三个问题：
1. 模型凭自己的知识会做错吗？
2. 这个任务会重复发生吗？
3. 正确做法有「坑」需要记录吗？

**三个「否」→ 不写。** 写 Skill 是为了「防止模型犯错」，不是为了复用而写。

### Step 2：定义触发条件（Description 写作）

**错误写法**（描述功能）：`Helps with database migrations`

**正确写法**（描述加载时机）：`Load when user mentions "migration", "rollback", "schema change", "ALTER TABLE"`

**黄金公式**：`Load when [用户关键词/动作] + [场景限定] + [必要时加负向限定]`

Description 决定了 Index 税是否花得值。

### Step 3：构建 SKILL.md 核心内容

```markdown
---
name: skill-name
description: Load when [触发条件]
---

# Skill 名称

## 核心规则（必须遵守）
- 规则1
- 规则2

## 工作流程 / 检查点
1. 第一步
2. 第二步

## 常见错误
- 错误场景 → 正确做法

## 参考
- 详细规范见 `references/xxx.md`
```

**关键**：
- 只写「模型不知道的」——模型会 `git add`，不用写；但「永远不要 force push 到 main」必须写
- SKILL.md 承载路由+核心规则，不是百科全书
- 核心规则控制在 10 条以内

### Step 4：决定是否需要附属文件

| 文件 | 何时需要 | 何时不需要 |
|------|---------|-----------|
| `scripts/` | 有确定性代码逻辑 | 模型可以现场手写 |
| `references/` | 有大型规范/Schema/API 文档 | 内容 < 2000 tokens |
| `assets/` | 需要固定模板 | 可用文字描述 |
| `examples/` | 输出有歧义需对齐 | 输出格式单一 |

**原则**：能不放就不放。每个附属文件都是一笔运行时税。

### Step 5：验收与测试

使用 OpenAI 四维验证体系：
1. **Outcome**：结果正确吗？
2. **Process**：过程对吗？（如备份前不能迁移）
3. **Style**：风格一致吗？（commit message、代码格式）
4. **Efficiency**：效率够吗？有无多余调用

**手测流程**：
1. 干净会话，只加载这个 Skill
2. 输入典型触发请求
3. 观察是否加载、过程是否符合预期
4. 标记「模型自己就会」的内容 → 删除

### Step 6：持续维护

Skill 是活的。维护节奏：
- 每月 review 使用率最低的 20% Skill，考虑删除/合并
- 用户反馈 Agent 失败 → 分析是否 Skill 内容问题
- 模型大版本升级 → 检查哪些规则已冗余


## 三、核心写作技巧

### 技巧 1：用「否定式规则」代替「肯定式指南」

| 不推荐 | 推荐 |
|--------|------|
| 你应该在修改前备份 | 没有备份之前，不要执行修改 |
| 建议使用 with 语句 | 永远不要用 open() 而不加 with |

**原因**：模型在长上下文中对「禁止项」比「应该项」更敏感。

### 技巧 2：分层披露——SKILL.md 只说「去哪里找」

```markdown
## 代码审查规则
完整清单见 `references/code_review_checklist.md`

关键规则摘要：
- 安全相关规则必须通过，否则直接驳回
```

### 技巧 3：用「检查点」替代「长流程描述」

```markdown
## 检查点 1：A 执行完成
验证条件：输出中包含 "SUCCESS"
通过 → 进入检查点 2
失败 → 返回 Step 1
```

### 技巧 4：Inversion 模式——给模型「对话出口」

```markdown
## 信息不足时的处理
当用户没有提供以下信息时，必须先询问，不得自行假设：
1. 目标环境（staging/production）
2. 是否需要备份
3. 变更影响范围
```

### 技巧 5：保持「原子性」

一个 Skill 只做一件事。`react_component`、`api_design`、`db_migration` 优于 `full_stack_development`。


## 四、规范清单

### 命名规范
- 全小写，只含字母、数字、连字符：`db-migration` ✅ `DB_Migration` ❌
- 目录名与 name 完全一致
- 不长于 3 个词

### Description 规范
- 以 `Load when` 开头
- 包含触发关键词
- 必要时加负向限定
- 不超过 200 字符

### 目录结构
```
skill-name/
├── SKILL.md
├── scripts/
├── references/
├── assets/
└── examples/
```
**禁止**：references/ 中嵌套深层目录，最多一层。


## 五、评估与优化（新版 skill-creator 体系）

### 触发评估指标

| 指标 | 公式 | 含义 |
|------|------|------|
| Precision | TP/(TP+FP) | 触发时的准确率 |
| Recall | TP/(TP+FN) | 覆盖率 |
| Accuracy | (TP+TN)/Total | 总体准确率 |

### 功能评估
- **Pass Rate**：通过断言数/总断言数
- **性能指标**：时间、Token、工具调用次数、错误数
- **Delta 计算**：with_skill vs without_skill 的差异

### Subagent 四角色设计

| 角色 | 职责 | 输出 |
|------|------|------|
| Executor | 执行任务 | transcript + 输出文件 |
| Grader | 按断言打分 | grading.json |
| Comparator | 双盲 A/B 比较 | comparison.json |
| Analyzer | 归因分析+改进建议 | analysis.json |

**关键设计理念**：
- 物理隔离确保客观（Subagent 隔离上下文）
- Grader 不仅核对 Rubric，还提取隐性声明做事实核查
- 双盲比较避免偏见
- 非单一指标，关注方差和异常值


## 六、注意事项（坑与避坑）

### ⚠️ 坑 1：SKILL.md 写成操作手册
模型本来就会 `npm install`，只写「非标准」部分：「这个项目用 PNPM，不是 npm」。

### ⚠️ 坑 2：Description 写成功能介绍
Agent 无法判断「什么时候该加载」。必须用 `Load when` + 触发词。

### ⚠️ 坑 3：一个 Skill 塞太多内容
Perplexity 教训：1945 条税法塞进一个 Skill，表现比不用还差。超过模型「多选一精度阈值」（几十到一百多），模型开始随机选择。

### ⚠️ 坑 4：忽略运行时税
如果 Agent 需要读三次以上 reference 才能完成任务，说明 reference 应精简或合并进 SKILL.md。

### ⚠️ 坑 5：从未更新 Skill
Skill 是活的。模型能力在提升，团队规范在变化。


## 七、快速自查表

| 检查项 | 通过标准 |
|--------|---------|
| 原子性 | 一个 Skill 只解决一类任务 |
| 必要性 | 没有这个 Skill，模型会犯错 |
| Description 可路由 | 以「Load when」开头，包含触发词 |
| 只写「模型不知道的」 | 没有 `git add` 这类基础命令 |
| 核心规则 ≤ 10 条 | 超过则拆分 |
| 附属文件有加载条件 | SKILL.md 中明确写了「见 xxx」 |
| 有检查点或显式流程 | 顺序敏感的任务有明确步骤 |
| 信息不足时有「问」的指令 | 不是猜，不是编 |
| 通过四维 Eval | Outcome + Process + Style + Efficiency |
| 有维护计划 | 知道什么时候更新/删除 |


> **最后一句话**：写 Skill 不是在写文档，而是在为模型设计「程序性知识的载体」。每一条指令、每一处省略，都在决定 Agent 能不能在真实世界中「干对活」。
