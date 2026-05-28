# 三维风险建模

## 评分公式

```
Risk_Score = 参数校验因子 × 高危参数因子 × 业务意义因子
```

**乘法模型说明**：采用乘法而非加法，因为纵深防御中任何一层的强防护都能显著降低整体风险。若某因子为 1（强防护），整体风险被压制。

## 一票否决

若参数校验发现以下情况，直接标记 `priority: LOW`，`score=1`，不再进入后续审计：
- 强正则白名单校验（如 `@Pattern(regexp = "^[a-zA-Z0-9]+$")`）
- 枚举类型参数（如 `@RequestParam Status status`，Status 为 enum）
- 框架自动类型转换且无自定义解析器（如 `@RequestParam Long id`）

## 因子分值表

统一：LOW=1，MEDIUM=3，HIGH=5

### 参数校验因子（Validation）

| 等级 | 分值 | 条件 |
|------|------|------|
| LOW | 1 | 强正则 / 白名单 / 本地净化 / 枚举类型 |
| MEDIUM | 3 | 基础类型校验 / 长度限制 / 范围约束 |
| HIGH | 5 | 零校验（裸奔接口）/ String 类型无约束 / 弱校验 |

### 高危参数因子（DangerousParam）

| 等级 | 分值 | 条件 |
|------|------|------|
| LOW | 1 | 无敏感参数（纯数字 ID、枚举、布尔值） |
| MEDIUM | 3 | 有限敏感参数（用户名、邮箱、普通文本） |
| HIGH | 5 | 高危参数（文件路径、SQL 片段、命令、URL、模板表达式、XML、LDAP 查询、序列化数据） |

### 业务意义因子（BusinessImpact）

| 等级 | 分值 | 条件 |
|------|------|------|
| LOW | 1 | 测试接口 / 演示接口 / 已废弃接口 / 健康检查 |
| MEDIUM | 3 | 普通业务接口（查询、列表、非敏感更新、日志记录） |
| HIGH | 5 | 核心业务接口（交易、支付、权限变更、敏感数据读写、管理操作、认证登录、添加/删除资源） |

## 风险等级与动作

| 风险等级 | 分值范围 | 动作 |
|----------|----------|------|
| CRITICAL | ≥ 60 | 必须进入 java-api-audit 进行 Source→Sink 分析 |
| HIGH | 15-59 | 必须进入 java-api-audit 进行 Source→Sink 分析 |
| MEDIUM | 3-14 | 可选择性进入 java-api-audit |
| LOW | 1 | 强制熔断，仅记录到清单，不审计 |

## 评分示例

| 端点 | 参数校验 | 高危参数 | 业务意义 | Score | 等级 |
|------|----------|----------|----------|-------|------|
| GET /api/users/{id} | 1 (Long类型) | 1 (数字ID) | 3 (查询) | 3 | MEDIUM |
| POST /api/files/upload | 5 (MultipartFile) | 5 (文件操作) | 5 (添加资源) | 125 | CRITICAL |
| POST /api/login | 5 (String用户名/密码) | 3 (认证相关) | 5 (认证) | 75 | CRITICAL |
| GET /api/health | 1 (无参数) | 1 (无敏感) | 1 (健康检查) | 1 | LOW |
| POST /api/users/{id}/role | 5 (String角色) | 5 (权限变更) | 5 (管理操作) | 125 | CRITICAL |
