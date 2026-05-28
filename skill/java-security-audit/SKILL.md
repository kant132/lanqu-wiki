---
name: java-security-audit
description: Java 正向安全审计调度Agent。当用户请求 Java 代码安全审计、Web 漏洞评估、Filter/Interceptor 安全分析、API 路由映射、SSRF/SQL注入/路径穿越/反序列化/XXE/SSTI/JNDI注入测试时加载。调度 Phase 1-5 五个子Skill完成全流程审计。Use this skill whenever the user mentions Java security audit, web vulnerability assessment, filter/interceptor analysis, API route mapping, taint analysis, or any Java web application security review.
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
---

# Java 正向安全审计 - 调度Agent

## 核心设计契约

| 契约 | 说明 |
|------|------|
| **断言即契约** | 每个审计阶段必须执行布尔条件判定，任一强制断言未评估，立即触发快速失败 |
| **格式即协议** | 严格按照预设Markdown结构输出，禁止大段自由发挥 |
| **LSP即真相** | 涉及自定义方法、跨类调用、属性共享时，必须通过 `textDocument/definition` 展开，拒绝黑盒猜测 |
| **总量守恒** | Phase 1 初始化的资产总数必须 ≥ 后续各阶段实际审计的资产数，缺失资产必须记录原因，理想情况为 == |

> 共享契约详见 [`references/shared-contracts.md`](references/shared-contracts.md)

## 五阶段流水线概览

| 阶段 | 子Skill | 核心任务 |
|------|---------|----------|
| Phase 1 | `java-recon` | 项目分析初始化 - 依赖拓扑识别、组件发现、资产台账建立 |
| Phase 2 | `java-filter-audit` | Filter/SecurityFilterChain核心审计 - 自定义Filter + Spring Security配置强制遍历（P1-P7） |
| Phase 3 | `java-interceptor-audit` | 拦截器及静态资源审计 - 配置层横向断言、路径走私检测 |
| Phase 4 | `java-lsp-trace` | LSP污点追踪与信任链审计 - 符号展开、属性污染追踪 |
| Phase 5 | `java-api-risk` | API路由与参数污点分析 - 动态决策引擎、五维风险建模 |

## 调度状态机

```
                     ┌─────────────┐
                     │   START     │
                     └──────┬──────┘
                            │
                     ┌──────▼──────┐
                     │  Phase 1    │
                     │ (java-recon)│
                     └──────┬──────┘
                            │
                     ┌──────▼──────┐
                     │  Phase 2    │
                     │(java-filter)│
                     └──────┬──────┘
                            │
                     ┌──────▼──────┐
                     │  Phase 3    │
                     │(java-intc)  │
                     └──────┬──────┘
                            │
                     ┌──────▼──────┐
                     │ 合并熔断状态 │
                     │ (Step 3)   │
                     └──────┬──────┘
                            │
            ┌───────────────┴───────────────┐
            │  degraded_mode 判定            │
            │  true → 跳过 P4，使用空结果    │
            │  false → 继续                 │
            └───────────────┬───────────────┘
                            │
                     ┌──────▼──────┐
                     │  Phase 4    │◄──┐ 回溯循环
                     │ (java-lsp)  │   │ (max 5次)
                     └──────┬──────┘   │ input_type="backtrack"
                            │          │ 每次回溯需
                     ┌──────▼──────┐   │ 重新调用
                     │  Phase 5    │───┘ P4→P5→P4
                     │ (java-api)  │
                     └──────┬──────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
       ┌──────▼──────┐            ┌──────▼──────┐
       │ Step 6      │            │ Step 7      │
       │ 回溯循环     │            │ 横向扩展    │
       │ (max 5次)   │            │ (max 3次)  │
       │ 串行优先    │            │ 串行在后    │
       └──────┬──────┘            └──────┬──────┘
              │                         │
              └─────────────┬───────────┘
                            │
                     ┌──────▼──────┐
                     │   REPORT    │
                     └─────────────┘
```

**图例**:
- `◄──┐` 表示反馈依赖（上游步骤依赖下游输出）
- `degraded_mode = true` 时，Phase 4 直接返回空结果并传递给 Phase 5，不执行 LSP 追踪

## 执行前提

在开始审计前，必须满足：

1. **环境要求**：LSP 服务器必须正常运行
2. **项目要求**：存在 pom.xml 或 build.gradle
3. **子 Skill 可达**：java-recon / java-filter-audit / java-interceptor-audit / java-lsp-trace / java-api-risk 五个子 Skill 必须已安装且可通过 Task 子Agent 加载
4. **Phase 1 成功**：engines.size() > 0，filters/security_configs/interceptors 资产台账已建立

## 典型执行路径

### 路径 A：正常路径（无回溯）
```
START → P1 → P2 → P3 → 熔断合并 → P4 → P5 → REPORT
```

### 路径 B：有回溯（≤5次）
```
START → P1 → P2 → P3 → 熔断合并 → P4 → P5 → [回溯1] → P4 → P5 → [回溯2] → ... → REPORT
```

### 路径 C：快速失败路径
```
START → P1 → ERR-NO-ENGINE → 终止
START → P1 → ERR-EMPTY-INVENTORY → 终止
P4 → ERR-LSP-TIMEOUT → 终止
回溯循环 → ERR-BACKTRACK-LIMIT → 继续到 REPORT（标记 untracked）
```

### 路径 D：降级模式（Phase 2/3 均失败）
```
START → P1 → P2(FAIL) → P3(FAIL) → 熔断合并 → 跳过P4 → P5(降级) → REPORT
```

### 路径 E：无防护项目（WARN-NO-GUARD）
```
START → P1 → filters=0, interceptors=0, security_configs=0 → 跳过P2/P3 → P4(无FAIL输入) → P5 → REPORT
```

## 执行流程

### Step 1: 调用 Phase 1（java-recon）

```
Task: 调用 java-recon skill
输入: 项目根路径
输出: Asset-Inventory JSON

验证:
- C1-C5 断言全部评估
- 若 ERR-NO-BUILD → 快速失败
- 若 ERR-NO-ENGINE → 快速失败
- 记录 filters、security_configs 和 interceptors 数量
```

### Step 2: 调用 Phase 2/3

```
执行前提: Phase 1 已成功完成，且 engines.size() > 0

Phase 2 资产范围（三类 Filter 配置，全部必须审计）:
  A. 自定义 Filter: implements Filter / extends OncePerRequestFilter / extends GenericFilterBean
  B. Spring Security: SecurityFilterChain Bean 配置（@EnableWebSecurity + filterChain 方法）
  C. web.xml Filter: <filter> 声明（传统 Servlet 项目）

条件分支:
  - engines.size() == 0 → 触发 ERR-NO-ENGINE，快速失败
  - filters.size() > 0 OR security_configs.size() > 0 → 调用 java-filter-audit（审计全部 Filter 配置）
  - interceptors.size() > 0 → 调用 java-interceptor-audit
  - 三者均为 0 → WARN-NO-GUARD，记录警告，继续执行 Phase 4/5（依赖纵向防御评估）

调度执行（串行，按条件调用）:
  if filters.size() > 0 OR security_configs.size() > 0:
    Task A: 调用 java-filter-audit skill (输入: Asset-Inventory，包含 filters + security_configs)
    等待 Task A 完成，获取结果
  else:
    Task A 结果为空集: { "phase": "Phase 2", "assertions": [], "circuit_breakers": [] }
  if interceptors.size() > 0:
    Task B: 调用 java-interceptor-audit skill (输入: Asset-Inventory)
    等待 Task B 完成，获取结果
  else:
    Task B 结果为空集: { "phase": "Phase 3", "assertions": [], "circuit_breakers": [] }

结果合并: 将 Task A 和 Task B 的 assertions 和 circuit_breakers 列表拼接，按 id 去重

**降级模式判定条件**:
  - 若 Task A 和 Task B 均返回空结果集（`assertions = []`）→ Step 3.5 中 `degraded_mode = true`
  - 否则 → Step 3.5 中 `degraded_mode = false`

验证: Phase 2/3 的资产总数必须 ≤ Phase 1 的 filters + security_configs + interceptors 总数
```

### Step 3: 合并熔断状态

```
输入: Phase2.circuit_breakers, Phase3.circuit_breakers
输出: merged_circuit_breakers

合并: 按 shared-contracts.md 中 merge() 函数执行（severity 高覆盖低，非固定优先级）
缺失资产: 记录 Phase 1 有但 Phase 2/3 未审计的资产（用于资产守恒验证）

熔断→五维因子映射（因子取值 1/3/5，熔断强制覆盖为 5）:
  - filter_bypassed → 全局过滤因子 = 5
  - interceptor_bypassed → 鉴权因子 = 5
  - 仅一项 bypassed → 仅覆盖对应因子为 5，其余因子由 Phase 5 自行评估
  - 两者均正常 → 所有因子由 Phase 5 自行评估，不做覆盖

Phase 5 风险评分 = 鉴权因子 × 全局过滤因子 × 参数校验因子 × 高危参数 × 业务意义

详细熔断传播规则见 shared-contracts.md
```

### Step 3.5: 传递调度状态（降级模式 / 正常模式）

调度 Agent 必须在本步骤中计算并向下传递以下状态：

| 状态变量 | 计算规则 | 传递目标 |
|----------|----------|-----------|
| `degraded_mode` | Phase2 和 Phase3 均返回空结果集（`assertions = []`） | Step 4、Step 5 |
| `phase4_input_mode` | `degraded_mode == true` → `"skipped_degraded"`<br>`degraded_mode == false` → `"scheduled"` | Step 4 |
| `phase5_degraded_flags` | `degraded_mode == true` 时传入：`max_backtrack=2`, `threshold=MEDIUM`<br>`degraded_mode == false` 时传入：`max_backtrack=5`, `threshold=HIGH/CRITICAL` | Step 5 |
| `overridden_factors` | 按 Step 3 熔断映射结果填充（见下方数据结构） | Step 5 |

**状态传递数据结构**（内部变量，调度 Agent 使用，不传入子 Skill）：

```json
{
  "调度状态": {
    "degraded_mode": false,
    "phase4_input_mode": "scheduled",
    "phase5_input": {
      "max_backtrack": 5,
      "lateral_expand_threshold": "HIGH"
    }
  }
}
```

**降级模式触发后的传递示例**：

```json
{
  "调度状态": {
    "degraded_mode": true,
    "phase4_input_mode": "skipped_degraded",
    "phase5_input": {
      "max_backtrack": 2,
      "lateral_expand_threshold": "MEDIUM",
      "phase4_results": {
        "phase": "Phase 4",
        "assertions": [],
        "circuit_breakers": [],
        "status": "skipped_degraded"
      }
    }
  }
}
```

### Step 4: 调用 Phase 4（java-lsp-trace）

```
输入来源（互斥，判定规则）:
  - phase4_input_mode = "backtrack" → input_type = "backtrack"（来自 Step 6 回溯循环）
  - phase4_input_mode = "skipped_degraded" → 直接跳过 Step 4，使用空结果
  - phase4_input_mode = "scheduled" → input_type = "scheduled"（调度主流程首次调用）

Task: 调用 java-lsp-trace skill
输入:
  - 项目根路径
  - 调用来源标识: input_type = "scheduled" | "backtrack"
  - 若 input_type = "scheduled":
      - Phase 2/3 的 FAIL 断言列表
      - 熔断状态 (merged_circuit_breakers)
  - 若 input_type = "backtrack":
      - Backtrack-Request JSON（包含 target_method, target_file, target_line, trace_depth）
  - MAX_LSP_DEPTH = 3

输出: Phase-Result JSON
  - 其中 circuit_breakers 携带 lsp_unresolved 标记（用于 Phase 5 confidence 降级）

快速失败: LSP 跳转深度超出 MAX_LSP_DEPTH(3) → ERR-LSP-DEPTH；LSP 单次操作超 30s → ERR-LSP-TIMEOUT（由 LSP 工具自身超时机制触发）

跳过逻辑（degraded_mode = true）:
  - 不调用 java-lsp-trace
  - 直接返回空 Phase-Result: { "phase": "Phase 4", "assertions": [], "circuit_breakers": [], "status": "skipped_degraded" }
  - 将该空结果传入 Step 5
```

### Step 5: 调用 Phase 5（java-api-risk）

```
Task: 调用 java-api-risk skill
输入:
  - Asset-Inventory JSON
  - 熔断传播状态:
      - merged_circuit_breakers（来自 Step 3）
      - 被覆盖的因子列表（如: 全局过滤因子=5, 鉴权因子=5）
  - Phase 4 完整结果（用于信任链分析和污点追踪）
  - MAX_BACKTRACK（来自调度状态: degraded_mode=true → 2, 正常 → 5）
  - MAX_LATERAL_EXPAND = 3
  - 风险阈值（来自调度状态: degraded_mode=true → MEDIUM+, 正常 → HIGH/CRITICAL+）
  - degraded_mode 标识（影响输出报告中是否标记 "degraded_mode: true"）

输出: 动态审计报告
  - findings: 漏洞发现列表
  - backtrack_requests: 回溯请求列表（供 Step 6 处理）
  - lateral_expand_requests: 横向扩展请求列表（供 Step 7 处理）
  - status: "complete" | "partial" | "max_iteration_reached"
  - degraded_mode: true（仅当降级模式触发时）

降级模式说明（由调度 Agent 控制，Phase 5 被动接收）:
  - 触发条件: Phase 2 和 Phase 3 均返回空结果集
  - Phase 4 被跳过时，向 Phase 5 传入: phase4_results = { "phase": "Phase 4", "assertions": [], "circuit_breakers": [], "status": "skipped_degraded" }
  - MAX_BACKTRACK 从 5 降为 2（减少无效追踪）
  - 风险等级阈值: MEDIUM 及以上端点均触发审计（正常模式仅 HIGH/CRITICAL）
```

> **执行顺序约定**: Step 6（回溯循环）和 Step 7（横向扩展）必须串行执行，回溯完全结束后才执行横向扩展，不可交错。

### Step 6: 处理回溯请求

```
输入: Phase 5 主流程输出的 backtrack_requests 列表（首次迭代）
      Phase 5 回溯迭代输出的 backtrack_requests 列表（第 N 次迭代）
前置条件: backtrack_count = 0

执行策略: 串行执行（每次回溯依赖前一次结果，不可并行）

循环控制:
  while backtrack_requests_from_latest_phase5.length > 0 AND backtrack_count < MAX_BACKTRACK(5):
      1. 从最新 Phase 5 输出中提取 next_backtrack_request: { target_method, target_file, target_line, trace_depth }
      2. 调用 Phase 4（input_type = "backtrack"，输入为 next_backtrack_request）
      3. 将 Phase 4 结果追加到 backtrack_history: push(backtrack_history, phase4_result)
      4. 构建 Phase 5 重新输入:
         - asset_inventory = （原始）
         - circuit_breakers = merged_circuit_breakers（原始）
         - overridden_factors = （来自 Step 3.5）
         - phase4_results = phase4_result（最新一次回溯结果）
         - backtrack_results = backtrack_history（所有历史结果数组）
         - current_backtrack_index = backtrack_count + 1
         - input_type = "backtrack"
      5. 重新调用 Phase 5
      6. backtrack_count += 1
      7. 从 Phase 5 重新输出中提取下一轮 backtrack_requests（循环依赖自身输出）

终止条件:
  - backtrack_count >= 5 → 触发 ERR-BACKTRACK-LIMIT，标记剩余 Backtrack-Request 为 untracked
  - 重新调用的 Phase 5 不再产生 backtrack_requests → 正常终止
  - Phase 5 输出 status = "max_iteration_reached" → 强制终止

结果合并策略:
  - backtrack_history 追加到最终报告的 Phase 4 章节
  - 每次 Phase 5 重新调用的 findings 追加到主 findings 列表
```

**Phase 5 回溯重新输入协议**：

```json
{
  "asset_inventory": { /* 原始 Asset-Inventory JSON */ },
  "circuit_breakers": { /* 原始 merged_circuit_breakers */ },
  "overridden_factors": { /* 来自 Step 3.5 */ },
  "phase4_results": { /* 最新一次 Phase 4 回溯结果 */ },
  "backtrack_results": [ /* 历史 Phase 4 结果数组（第1次到第N次） */ ],
  "current_backtrack_index": 1,
  "input_type": "backtrack",
  "max_backtrack": 5,
  "max_lateral_expand": 3,
  "degraded_mode": false
}
```

### Step 7: 处理横向扩展请求

```
输入: Phase 5 输出的 lateral_expand_requests 列表
前置条件: lateral_expand_count = 0，MAX_LATERAL_EXPAND = 3

执行策略: 串行执行，每次横向扩展依赖前一次 Phase 5 的输出结果

循环控制:
  while Phase5.output.lateral_expand_requests.length > 0 AND lateral_expand_count < MAX_LATERAL_EXPAND:
      1. 从 Phase 5 输出中提取 next_lateral_request: { new_endpoints: [ { path, controller, reason } ] }
      2. 将 new_endpoints 加入待审计端点队列（追加，不去重）
      3. 调用 Phase 5（input_type = "lateral_expand"）
         - 输入: Asset-Inventory + 熔断状态 + phase4_results（不重新调用 P4）
         - 附加: lateral_expand_endpoints = next_lateral_request.new_endpoints
         - 附加: lateral_expand_index = lateral_expand_count + 1
      4. 将 Phase 5 输出的 findings 追加到主 findings 列表（不去重，已有关联ID不覆盖）
      5. 将 Phase 5 输出的 backtrack_requests 和 lateral_expand_requests 加入各自的待处理队列
      6. lateral_expand_count += 1
      7. 判断 Phase 5 是否产生新的 Lateral-Expand-Request（循环依赖自身输出）

终止条件:
  - lateral_expand_count >= 3 → 记录 WARN-LATERAL-LIMIT，跳过剩余扩展请求
  - Phase 5 不再产生 Lateral-Expand-Request → 正常终止

输入类型标识:
  - input_type = "lateral_expand"（供 Phase 5 内部路由映射逻辑识别）
```

**Phase 5 横向扩展输入协议**：

```json
{
  "asset_inventory": { /* Asset-Inventory JSON */ },
  "circuit_breakers": { /* merged_circuit_breakers */ },
  "overridden_factors": { /* 来自 Step 3.5 */ },
  "phase4_results": { /* 当前 Phase 4 结果，不重新调用 */ },
  "backtrack_results": [ /* 当前回溯历史（若有） */ ],
  "input_type": "lateral_expand",
  "lateral_expand_endpoints": [
    {
      "path": "GET /api/v1/files/{fileId}",
      "controller": "FileController",
      "reason": "从 download 方法追踪发现关联端点"
    }
  ],
  "lateral_expand_index": 1,
  "max_backtrack": 5,
  "max_lateral_expand": 3
}
```

### Step 8: 生成最终报告

```
汇总所有 Phase 输出:
  - Phase 1: 资产台账
  - Phase 2: Filter 断言报告
  - Phase 3: Interceptor 断言报告
  - Phase 4: LSP 追踪报告
  - Phase 5: 动态审计报告
  - backtrack_results: 追加到 Phase 4 相关章节

资产守恒验证: total_assets_from_P1 >= total_assets_audited_by_P2+P3（若有缺失资产，必须记录原因和影响范围）

生成最终门禁汇总:
  > 详见 references/final-summary-output.md
```

## 最终报告模板

> 详见 [`references/final-summary-output.md`](references/final-summary-output.md)，按 `[FINAL_SUMMARY_REPORT]` 格式输出

## 快速失败错误码

> 完整定义及触发条件见 [`references/shared-contracts.md`](references/shared-contracts.md)
