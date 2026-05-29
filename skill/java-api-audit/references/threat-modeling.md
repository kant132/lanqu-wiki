# STRIDE 威胁建模

## 1. 建模时机

在 API 正向污点审计（检查点 5）**之前**执行，用于：
- 识别高价值攻击目标
- 指导审计优先级（不完全依赖三维评分）
- 发现纯代码审计容易遗漏的架构级风险

## 2. 建模流程

### Step 1: 攻击面枚举

```
从 Phase 1-3 的输出中提取:

1. 外部攻击面（未认证可达）:
   - SecurityFilterChain permitAll 路径 ∩ API 端点清单
   - 输出: 未认证端点列表 + HTTP 方法 + 参数

2. 内部攻击面（认证后可达）:
   - 所有需要认证的 API 端点
   - 按角色分组（若有 RBAC）

3. 数据攻击面:
   - 数据库表清单（从 JPA Entity / Flyway 迁移脚本提取）
   - 敏感数据表标记（users, payments, credentials, tokens）

4. 集成攻击面:
   - 外部 HTTP 调用（RestTemplate/WebClient 目标 URL）
   - 消息队列（RabbitMQ/Kafka topic）
   - 第三方 API 集成
```

### Step 2: STRIDE 威胁识别

对每个攻击面，按 STRIDE 模型识别威胁：

| STRIDE | 含义 | 检查项 | 审计方法 |
|--------|------|--------|----------|
| **S**poofing | 身份伪造 | 认证机制是否可绕过？JWT/Session 是否可伪造？ | 审计认证 Filter + Token 验证逻辑 |
| **T**ampering | 数据篡改 | 输入是否可篡改关键数据？SQL注入/参数篡改？ | Source→Sink 污点追踪 |
| **R**epudiation | 抵赖 | 关键操作是否有审计日志？日志是否可被注入？ | 审计日志写入逻辑 |
| **I**nformation Disclosure | 信息泄露 | 错误消息/堆栈/Actuator 是否泄露敏感信息？ | 审计异常处理 + 配置 |
| **D**enial of Service | 拒绝服务 | 是否存在资源耗尽入口？无限制的查询/文件上传？ | 审计资源消耗型操作 |
| **E**levation of Privilege | 权限提升 | 是否可越权访问？IDOR/角色绕过？ | 审计授权检查逻辑 |

### Step 3: 攻击树构建

```
对每个高价值目标构建攻击树:

目标: 获取数据库全部数据
├── 路径1: SQL注入
│   ├── 子路径1.1: 直接 SQL 注入（字符串拼接查询）
│   ├── 子路径1.2: 二阶 SQL 注入（存储后读取拼接）
│   └── 子路径1.3: ORDER BY 注入
├── 路径2: 反序列化 RCE → 直接读取数据库文件
│   ├── 子路径2.1: ObjectInputStream.readObject()
│   └── 子路径2.2: XStream.fromXML()
├── 路径3: SSRF → 访问内部数据库管理接口
│   └── 子路径3.1: URL.openStream() 无白名单
└── 路径4: 配置文件泄露 → 获取数据库凭证
    ├── 子路径4.1: /actuator/env 暴露
    └── 子路径4.2: /actuator/configprops 暴露

目标: 以管理员身份操作
├── 路径1: 密码破解/泄露
│   ├── 子路径1.1: NoOpPasswordEncoder → 数据库泄露即全部沦陷
│   └── 子路径1.2: 硬编码默认密码
├── 路径2: JWT 伪造
│   ├── 子路径2.1: 弱密钥爆破
│   ├── 子路径2.2: alg=none 绕过
│   └── 子路径2.3: kid SQL 注入获取密钥
└── 路径3: Session 劫持
    ├── 子路径3.1: XSS → 窃取 Session Cookie
    └── 子路径3.2: 可预测 Session ID
```

### Step 4: 审计优先级生成

```
基于攻击树生成审计优先级（补充三维评分的不足）:

优先级规则:
  1. 攻击树的根节点对应的端点 → 最高优先级
  2. 多条攻击路径汇聚的端点 → 高优先级
  3. 未认证可达 + 高价值目标 → 高优先级
  4. 三维评分高但攻击树中无对应路径 → 降低优先级（可能是理论风险）
  5. 三维评分低但攻击树中是关键节点 → 提升优先级

输出: 补充审计队列（在三维评分队列基础上增加/调整优先级）
```

## 3. 输出格式

```markdown
## 威胁建模报告

### 攻击面总览

| 攻击面类型 | 入口点数 | 高价值目标 | 关键发现 |
|-----------|---------|-----------|----------|
| 外部(未认证) | {count} | {targets} | {findings} |
| 内部(认证后) | {count} | {targets} | {findings} |
| 数据层 | {count} | {targets} | {findings} |
| 集成层 | {count} | {targets} | {findings} |

### STRIDE 威胁清单

| # | STRIDE 类型 | 威胁描述 | 攻击入口 | 影响目标 | 严重度 | 审计优先级 |
|---|------------|----------|----------|----------|--------|-----------|
| 1 | Tampering | SQL注入获取全部数据 | POST /SqlInjection/attack8 | employees 表 | CRITICAL | P0 |

### 攻击树（Top 3 高价值目标）

#### 目标 1: {目标描述}
```
目标
├── 路径1: ...
├── 路径2: ...
└── 路径3: ...
```

### 审计优先级调整

| 端点 | 原优先级(三维评分) | 调整后优先级(威胁建模) | 调整理由 |
|------|-------------------|----------------------|----------|
| POST /SqlInjection/attack8 | P0 | P0 | 攻击树根节点 |
| GET /actuator/env | 未评分 | P0 | 配置泄露→数据库凭证 |
```

## 4. 确定性标注

| 步骤 | 确定性 | 说明 |
|------|--------|------|
| 攻击面枚举 — permitAll 路径提取 | DETERMINISTIC | SecurityFilterChain 配置解析 |
| 攻击面枚举 — API 端点提取 | DETERMINISTIC | 注解扫描 |
| 攻击面枚举 — 数据库表提取 | DETERMINISTIC | JPA Entity / Flyway 脚本解析 |
| STRIDE 威胁识别 | HEURISTIC | 基于模式匹配，可能遗漏非典型威胁 |
| 攻击树构建 | SUBJECTIVE | 需要安全专家经验，AI 可能遗漏创新攻击路径 |
| 审计优先级调整 | SUBJECTIVE | 需要权衡多个因素 |
