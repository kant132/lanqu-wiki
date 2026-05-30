# Skill 工程化提升方案

## 一、根因分析：为什么当前 Skill 工程化程度低？

### 核心矛盾

当前 skill 的本质是 **"用自然语言写的程序"**。但自然语言不是编程语言，它缺少：

| 编程语言特性 | 当前 Skill 状态 | 后果 |
|-------------|---------------|------|
| 确定性执行 | ❌ 同一指令每次执行结果不同 | 可重复性 45% |
| 类型系统 | ❌ 输入输出无 schema 约束 | 阶段间数据传递靠 AI "理解" |
| 错误处理 | ❌ 仅 3 个 ERR 码 | 中间步骤失败后无法恢复 |
| 循环/条件 | ❌ 用自然语言描述 "for each" | AI 可能跳过某些迭代 |
| 函数调用 | ❌ 无模块化复用 | 相同逻辑在多处重复描述 |
| 断言/测试 | ❌ 无输出验证 | 无法检测 AI 是否完成了所有步骤 |
| 参数化 | ❌ 无执行参数 | 无法控制深度/范围/速度 |

### 根本原因

**把 AI 当成了"全能的执行者"，而非"判断力的提供者"。**

当前设计假设 AI 能同时做好两件事：
1. **确定性计算**：扫描文件、匹配正则、提取注解、计数统计
2. **主观判断**：评估风险、理解业务、构建攻击树、生成 PoC

但 AI 擅长的是第 2 类，第 1 类应该交给脚本。

---

## 二、业界最佳实践

### 2.1 Anthropic 官方推荐（2024）

> "Use tools and structured outputs to make LLM behavior deterministic where possible. Reserve the LLM's judgment for tasks that genuinely require it."

核心原则：
- **Tool Use Pattern**: 让 LLM 调用工具（脚本），而非自己执行计算
- **Structured Output**: 用 JSON Schema 约束输出格式
- **Verification Step**: 每步输出后用脚本验证完整性
- **Chain of Thought + Verification**: 思考→执行→验证→修正

### 2.2 OpenAI Assistants API 模式

```
User Request → Planner (AI) → [Tool Calls] → Verifier (Script) → Response
                                  ↓
                          [code_interpreter]
                          [file_search]  
                          [function_call]
```

关键设计：
- **Planner**: AI 决定执行计划
- **Tool Calls**: 确定性任务调用脚本
- **Verifier**: 脚本验证 AI 输出是否完整

### 2.3 LangChain / LangGraph 模式

```python
# 状态机控制流程
graph = StateGraph(AuditState)
graph.add_node("recon", run_recon_script)        # 确定性
graph.add_node("analyze", ai_analyze)             # AI 判断
graph.add_node("verify", run_verification_script) # 确定性
graph.add_conditional_edges("verify", 
    lambda state: "complete" if state.valid else "analyze")
```

关键设计：
- **状态机**: 用代码控制流程，而非自然语言描述
- **确定性节点**: 扫描/提取/验证用脚本
- **AI 节点**: 分析/判断/生成用 LLM
- **条件边**: 验证失败时回退重做

### 2.4 Aider / Cursor 模式

```
AI 生成代码 → 自动运行 lint/test → 失败则 AI 修复 → 循环直到通过
```

关键设计：
- **自动反馈循环**: 脚本执行结果反馈给 AI
- **收敛保证**: 有明确的终止条件（测试通过）

### 2.5 总结：业界共识

```
┌─────────────────────────────────────────────────┐
│              最佳实践架构                         │
│                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ 脚本层   │ →  │ AI 层    │ →  │ 验证层   │  │
│  │(确定性)  │    │(判断力)  │    │(确定性)  │  │
│  └──────────┘    └──────────┘    └──────────┘  │
│       ↑                                │        │
│       └────────── 反馈循环 ────────────┘        │
│                                                 │
│  脚本做: 扫描、提取、匹配、计数、验证            │
│  AI 做: 分析、判断、推理、生成                   │
│  验证做: 完整性检查、格式校验、一致性验证         │
└─────────────────────────────────────────────────┘
```

---

## 三、脚本增强方案设计

### 3.1 核心原则

```
确定性任务 → 脚本（100% 可重复）
主观判断任务 → AI（标注置信度）
输出验证 → 脚本（自动检测遗漏）
```

### 3.2 哪些任务应该脚本化？

| 任务 | 当前方式 | 应改为 | 原因 |
|------|---------|--------|------|
| 扫描 @Controller/@RestController | AI 用 Grep | **脚本** | 正则匹配，100% 确定性 |
| 提取 @RequestMapping 路径 | AI 读取文件 | **脚本** | AST 解析，100% 确定性 |
| 提取 @RequestParam 参数 | AI 读取文件 | **脚本** | 正则匹配，100% 确定性 |
| 扫描 Sink 模式 | AI 用 Grep | **脚本** | 正则匹配，100% 确定性 |
| 提取 application.yml 配置 | AI 读取文件 | **脚本** | YAML 解析，100% 确定性 |
| 扫描 Filter/Interceptor 注册 | AI 用 Grep | **脚本** | 正则匹配，100% 确定性 |
| 计算三维风险评分 | AI 主观判断 | **脚本+AI** | 脚本计算确定性因子，AI 判断主观因子 |
| 验证输出完整性 | 无 | **脚本** | 检查必填段落、表格行数 |
| 评估消毒有效性 | AI 判断 | **脚本+AI** | 脚本查矩阵，AI 处理自定义函数 |
| 构建攻击树 | AI 推理 | **AI** | 纯判断力任务 |
| 生成 PoC | AI 生成 | **AI** | 纯判断力任务 |
| 业务影响评估 | AI 判断 | **AI** | 纯判断力任务 |

### 3.3 脚本架构

```
java-security-audit/
├── SKILL.md                    # 主流程编排（精简到 ~150 行）
├── scripts/
│   ├── recon.sh               # Phase 1: 项目侦察（确定性扫描）
│   ├── scan-sinks.sh          # Sink 模式扫描（确定性）
│   ├── extract-apis.sh        # API 端点提取（确定性）
│   ├── scan-configs.sh        # 配置文件扫描（确定性）
│   ├── calculate-risk.sh      # 风险评分计算（半确定性）
│   ├── validate-output.sh     # 输出完整性验证（确定性）
│   └── lib/
│       ├── common.sh          # 公共函数
│       └── patterns.json      # 正则模式库
├── references/
│   └── ...                    # 现有引用文件
└── templates/
    └── output-schema.json     # 输出 JSON Schema
```

### 3.4 脚本与 AI 的协作模式

```
Phase 1 执行流程:

1. [脚本] recon.sh 扫描项目
   → 输出: output/phase1-raw.json (结构化数据)
   
2. [AI] 读取 phase1-raw.json
   → 补充: 业务含义、框架版本解读、依赖风险评估
   → 输出: output/phase1-recon.md (人类可读报告)
   
3. [脚本] validate-output.sh phase1
   → 验证: 所有必填字段是否存在
   → 失败则: 提示 AI 补充缺失内容
```

---

## 四、具体实施方案

详见后续文件创建。
