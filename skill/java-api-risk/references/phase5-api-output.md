# Phase 5 输出模板

## API_TAINT_ALIGNMENT_AUDIT

```markdown
[API_TAINT_ALIGNMENT_AUDIT]
_detected_routing_layer: "Hybrid Stack (Spring MVC / JAX-RS / Servlet / RPC)"
_assertions_applied: ["R1", "R2", "R3", "R4", "R5"]

### 1. 异构 Web / RPC 路由资产全量暴露清单 (Total Route Inventory)

| 资产ID | 组件引擎 | 路由端点 (Path/Method) | 暴露类与方法签名 | 风险权重评分 | 算力路由决策 |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **ROUTE-001** | Spring MVC | `GET /api/v1/backup/download/{fileId}` | `BackupController.downloadBackup(...)` | **75 (CRITICAL)** | 启动 LSP 正向追踪 |
| **ROUTE-002** | JAX-RS | `DELETE /admin/v2/users/{username}` | `UserResource.deleteUser(...)` | 27 (MEDIUM) | 算力裁剪-选择性跳过 |
| **ROUTE-003** | Native Servlet | `POST /internal/dump.do` | `InternalDumpServlet.doPost(...)` | **75 (HIGH)** | 启动 LSP 正向追踪 |
| **ROUTE-004** | Dubbo RPC | `RPC com.secure...UserService:update` | `UserProviderImpl.updateUserInfo(...)` | 1 (LOW) | 算力裁剪-直接熔断 |

---

### 2. 重危资产正向污点流深度闭环分析 (ROUTE-001)

* **目标位置**: `BackupController.java:22`
* **前置防线审计结果**:
  * **JSR-303 声明式校验**: 无 (未标记 `@Valid` 或 `@Pattern`)
  * **编程式参数校验**: 无 (形参 `fileId` 直接进入业务流)
  * **四维因子权重**: 5 (Anonymous) × 3 (弱全局过滤) × 5 (零校验) = **75分**

#### 2.1 基于 LSP 的路由参数污点流向图 (LSP Route Parameter Taint Flow)

```
[LSP Source: @PathVariable("fileId")] (:22)
    │
    ▼ (LSP References: String path = "/data/shares/" + fileId;) (:28) ──> 参数零校验，未经过任何 Local_Sanitizer 净化
    │
    ▼ (LSP Definition: File file = new File(path);) (:30)
    │
    ▼ [Dangerous Sink] new FileInputStream(file) (:32) ──────────────────> 确认流向高危文件读取 Sink，链路闭合
```

#### 2.2 参数校验状态详情

| 校验类型 | 状态 | 说明 |
|----------|------|------|
| JSR-303声明式 | 无 | 未使用@Valid/@Pattern |
| 编程式校验 | 无 | 无if/throw校验 |
| 全局过滤 | 弱 | 仅日志记录 |
| 本地净化 | 无 | 直接进入业务流 |

---

### 3. 跨组件解析差异与污点闭航矩阵

| 输入向量 (PoC Payload) | 前级中间件路径匹配判定 | 后端路由实际解析与参数捕获结果 | LSP 污点流向与最终状态 |
| :--- | :--- | :--- | :--- |
| `GET /api/v1/backup/download/100` | 拦截（常规策略拦截） | 未触发后端核心方法 | 安全拦截 |
| `GET /api/v1/backup/download/..%252f..%252fpasswd;.js` | 放行（因前级 Filter 缺陷，Payload 以 `.js` 结尾，误判为静态资源） | 路由捕获参数：`fileId = ../../passwd` | 污点参数完美注入 Sink：零校验直达 FileInputStream，成功实现任意文件下载越权穿透 |
```

## Audit-Context.json 结构

```json
{
  "audit_meta": {
    "engine_mode": "Param-Modeler-Sandbox",
    "timestamp": "2026-05-27T11:20:00Z",
    "total_sources_extracted": 4,
    "frameworks_detected": ["Spring MVC", "JAX-RS", "Native Servlet", "Dubbo RPC"]
  },
  "api_route_assets": [
    {
      "asset_id": "ROUTE-001",
      "engine": "Spring MVC",
      "path": "GET /api/v1/backup/download/{fileId}",
      "mean": "文件下载接口-高危参数fileId对应文件路径",
      "next_step": "分析fileId参数是否可导致路径穿越/任意文件读取",
      "method": "GET",
      "controller_class": "com.secure.gateway.controller.BackupController",
      "method_signature": "downloadBackup(String fileId)",
      "parameters": [
        {
          "name": "fileId",
          "binding": "@PathVariable",
          "type": "java.lang.String"
        }
      ],
      "risk_modeling": {
        "factors": {
          "authentication": 5,
          "global_filter": 3,
          "validation": 5
        },
        "score": 75,
        "priority": "CRITICAL",
        "validation_detail": "Zero_Validation (No @Valid/@Pattern, direct use of parameter)",
        "trigger_deep_trace": true,
        "business_risk": {
          "business_scenario": "文件下载-内部文档管理",
          "data_sensitivity": "HIGH",
          "impact_scope": "全量用户",
          "sensitive_operations": ["file_read", "data_export"],
          "compliance_risks": ["个人信息", "知识产权"],
          "attack_vectors": ["路径穿越", "越权访问"]
        }
      }
    }
  ],
  "execution_queue": {
    "will_positive_trace_ids": ["ROUTE-001"],
    "skipped_low_risk_ids": ["ROUTE-004"]
  }
}
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `_detected_routing_layer` | String | 检测到的路由层类型 |
| `_assertions_applied` | Array[String] | 已应用的断言代码 |
| `api_route_assets` | Array[Object] | API路由资产清单 |
| `asset_id` | String | 资产ID，格式ROUTE-XXX |
| `engine` | String | 组件引擎类型 |
| `path` | String | 路由路径 |
| `mean` | String | 接口业务意义 |
| `next_step` | String | 下一步分析重点 |
| `risk_modeling` | Object | 风险模型数据 |
| `score` | INT | 风险评分 |
| `priority` | String | CRITICAL/HIGH/MEDIUM/LOW |
| `trigger_deep_trace` | Boolean | 是否触发深度追踪 |

## 示例

```markdown
[API_TAINT_ALIGNMENT_AUDIT]
_detected_routing_layer: "Hybrid Stack (Spring MVC / JAX-RS / Servlet / RPC)"
_assertions_applied: ["R1", "R2", "R3", "R4", "R5"]

### 1. 异构 Web / RPC 路由资产全量暴露清单 (Total Route Inventory)

| 资产ID | 组件引擎 | 路由端点 (Path/Method) | 暴露类与方法签名 | 风险权重评分 | 算力路由决策 |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **ROUTE-001** | Spring MVC | `GET /api/v1/backup/download/{fileId}` | `BackupController.downloadBackup(...)` | **75 (CRITICAL)** | 启动 LSP 正向追踪 |
| **ROUTE-002** | Spring MVC | `POST /api/v1/users/{id}/reset-pwd` | `UserController.resetPassword(...)` | **45 (HIGH)** | 启动 LSP 正向追踪 |

---

### 2. 重危资产正向污点流深度闭环分析 (ROUTE-001)

* **目标位置**: `BackupController.java:22`
* **前置防线审计结果**:
  * **JSR-303 声明式校验**: 无
  * **编程式参数校验**: 无
  * **四维因子权重**: 5 × 3 × 5 = **75分**

#### 2.1 LSP 路由参数污点流向图

```
[LSP Source: @PathVariable("fileId")] (:22)
    │
    ▼ (LSP References: String path = "/data/shares/" + fileId;) (:28)
    │
    ▼ (LSP Definition: File file = new File(path);) (:30)
    │
    ▼ [Dangerous Sink] new FileInputStream(file) (:32)
```

---

### 3. [API业务安全分析] ROUTE-001

#### 1. 业务上下文分析 (基于代码理解)

| 分析项 | 代码证据 | 推断结论 |
|--------|----------|----------|
| API用途 | `BackupController.downloadBackup(fileId)` | 文件下载功能 |
| 操作对象 | `fileId` 参数 (String) | 用户文件资源标识 |
| 调用链 | BackupController:22 → FileService:45 → FileRepository | 标准三层架构 |
| 业务规则 | Service层使用fileId查询文件 → 返回File对象 → 读取文件流 | 需要文件归属校验 |

#### 2. 识别的安全技术

| 技术类型 | 代码位置 | 实现细节 |
|----------|----------|----------|
| 认证 | `@PreAuthorize("isAuthenticated()")` @ BackupController:18 | 需要登录 |
| 授权 | `file.getOwnerId() == currentUserId` @ FileService:48 | 有归属校验，但可能存在时序问题 |
| 数据查询 | `FileRepository.findById(fileId)` | JPA自动参数化查询 |
| 文件读取 | `new FileInputStream(file)` @ BackupController:32 | 直接文件系统读取 |

#### 3. 潜在风险推导

基于代码分析，推导以下潜在风险：

| 风险类型 | 推导依据 | 验证状态 |
|----------|----------|----------|
| 越权访问 | fileId可控，归属校验在Service层执行 | 待验证：LSP追踪归属校验是否正确 |
| 路径穿越 | fileId直接拼接路径 `/data/shares/` + fileId | 待验证：是否检查 `..` |
| SQL注入 | 使用JPA参数化查询 | 低风险：Hibernate自动处理 |
| 认证绕过 | 注解在Controller层，可能被绕过 | 待验证：是否有其他入口 |

#### 4. 漏洞代码验证

| 漏洞 | 验证结果 | 代码证据 |
|------|----------|----------|
| 越权访问 | **存在** | `FileService:48` 归属校验在查询之后，先返回文件再校验 |
| 路径穿越 | **存在** | `BackupController:28` 直接拼接未检查 `..` |
| SQL注入 | 不存在 | 使用JPA findById自动参数化 |

#### 5. 业务影响评估

| 已验证漏洞 | 技术根因 | 业务影响 |
|-----------|----------|----------|
| 越权下载文件 | 归属校验时序错误：先返回文件后校验 | 用户可下载任意文件，包括其他用户文件 |
| 路径穿越 | fileId未净化直接拼接路径 | 可读取 `/data/shares/../../etc/passwd` 等敏感文件 |

---

### 4. [API业务安全分析] ROUTE-002

#### 1. 业务上下文分析 (基于代码理解)

| 分析项 | 代码证据 | 推断结论 |
|--------|----------|----------|
| API用途 | `UserController.resetPassword(userId, newPassword)` | 密码重置功能 |
| 操作对象 | `userId` (目标用户), `newPassword` (新密码) | 用户账号安全 |
| 调用链 | UserController → UserService → PasswordEncoder | 涉及密码加密存储 |
| 业务规则 | 需要验证旧密码 → 更新新密码 → 发送通知邮件 | 敏感操作需要身份验证 |

#### 2. 识别的安全技术

| 技术类型 | 代码位置 | 实现细节 |
|----------|----------|----------|
| 认证 | `@PreAuthorize("isAuthenticated()")` + 旧密码验证 | 双重认证 |
| 密码加密 | `BCryptPasswordEncoder.encode()` @ UserService:65 | BCrypt强哈希 |
| 会话管理 | `HttpSession.setAttribute("userId", userId)` | Session存储用户状态 |
| 邮件通知 | `EmailService.send()` @ UserService:78 | 密码修改通知 |

#### 3. 潜在风险推导

| 风险类型 | 推导依据 | 验证状态 |
|----------|----------|----------|
| 密码重置绕过 | 新密码参数可控，BCrypt加密后存储 | 低风险：密码被正确哈希 |
| 会话 fixation | userId存入会话，可能被会话 fixation攻击 | 待验证：会话是否刷新 |
| 邮箱验证绕过 | 密码重置后发送到邮箱，未验证邮箱有效性 | 中风险：需验证邮箱可达性 |
| 暴力破解 | 无账号锁定机制，可无限尝试 | 待验证：是否有rate limiting |

#### 4. 漏洞代码验证

| 漏洞 | 验证结果 | 代码证据 |
|------|----------|----------|
| 密码重置绕过 | 不存在 | 正确验证旧密码后才更新 |
| 会话 fixation | **存在** | `UserService:45` 未刷新session ID |
| 邮箱验证绕过 | **存在** | `UserService:70` 发送邮件但未验证邮箱所有权 |
| 暴力破解 | **存在** | 无账号锁定，密码重置接口可无限调用 |

#### 5. 业务影响评估

| 已验证漏洞 | 技术根因 | 业务影响 |
|-----------|----------|----------|
| 会话 fixation | 重置密码后session未刷新 | 攻击者可劫持会话 |
| 账号被盗 | 无暴力破解保护，攻击者无限尝试密码 | 用户账号可能被暴力破解 |
| 邮箱轰炸 | 无邮箱验证，无发送频率限制 | 攻击者向目标发送大量邮件 |

```