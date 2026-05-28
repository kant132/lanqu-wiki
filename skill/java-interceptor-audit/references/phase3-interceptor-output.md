# Phase 3 输出模板

## INTERCEPTOR_AUDIT

```markdown
[INTERCEPTOR_AUDIT]
_audit_id: "I_XXX"
_audit_target: "ClassName"
_assertions_applied: ["I1", "I2", "I3", "I4", "I5", "I6", "I7", "S1", "S2", "S3", "S4"]

### [H-IN-XXX] Interceptor 漏洞名称
* **组件位置**: `Interceptor` | `FileName:Line`
* **漏洞类型**: 详细分类
* **强制检查结果**:

| 断言 | 检查项 | 结果 | 证据 |
|------|--------|------|------|
| I1 | 拦截路径覆盖 | PASS/FAIL | 代码片段 |
| I2 | 白名单过宽风险 | PASS/FAIL | 代码片段 |
| I3 | 静态资源放行 | PASS/FAIL | 代码片段 |
| I4 | 宿主框架路由配置 | PASS/FAIL | 代码片段 |
| I5 | 尾部斜杠不一致性 | PASS/FAIL | 代码片段 |
| I6 | 注解符号追踪 | PASS/FAIL | 代码片段 |
| I7 | 配置层加载状态 | PASS/FAIL | 代码片段 |
| S1 | 放行路径枚举 | PASS/FAIL | 代码片段 |
| S2 | 路径走私断言 | PASS/FAIL | 代码片段 |
| S3 | 通配符绕过 | PASS/FAIL | 代码片段 |
| S4 | 目录穿越 | PASS/FAIL | 代码片段 |
```

## 静态资源放行专项

### 放行路径清单

| 路径模式 | 来源 | 匹配类型 |
|----------|------|----------|
| `/static/**` | WebMvcConfigurer | Ant |
| `/health` | Interceptor | PathPattern |

### 路径走私测试矩阵

| 原始路径 | 走私Payload | 测试结果 | 风险等级 |
|----------|-------------|----------|----------|
| `/static/**` | `..;/..;/etc/passwd` | 可越权访问 | HIGH |
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `_audit_id` | String | 审计ID，格式I_XXX |
| `_audit_target` | String | 目标类名 |
| `_assertions_applied` | Array[String] | 已应用的断言代码列表 |

## 示例

```markdown
[INTERCEPTOR_AUDIT]
_audit_id: "I_001"
_audit_target: "AuthInterceptor"
_assertions_applied: ["I1", "I2", "I3", "I4", "I5", "I6", "I7", "S1", "S2", "S3", "S4"]

### [H-IN-001] Interceptor 白名单过宽
* **组件位置**: `Interceptor` | `AuthInterceptor.java:23`
* **漏洞类型**: 白名单过宽 / 路径走私
* **强制检查结果**:

| 断言 | 检查项 | 结果 | 证据 |
|------|--------|------|------|
| I1 | 拦截路径覆盖 | PASS | addPathPatterns("/api/**") |
| I2 | 白名单过宽风险 | FAIL | excludePathPatterns("/api/v2/**")过宽 |
| I3 | 静态资源放行 | PASS | 正确使用handler instanceof |
| I4 | 宿主框架路由配置 | PASS | 使用默认UrlPathHelper |
| I5 | 尾部斜杠不一致性 | PASS | 无尾部斜杠处理差异 |
| I6 | 注解符号追踪 | N/A | 未使用自定义注解 |
| I7 | 配置层加载状态 | PASS | WebMvcConfigurer正确加载 |
| S1 | 放行路径枚举 | FAIL | 发现模糊放行路径 |
| S2 | 路径走私断言 | FAIL | ..;/可绕过 |
| S3 | 通配符绕过 | FAIL | //可绕过 |
| S4 | 目录穿越 | PASS | 静态目录已限制 |

## 静态资源放行专项

### 放行路径清单

| 路径模式 | 来源 | 匹配类型 |
|----------|------|----------|
| `/api/v2/**` | Interceptor | Ant |
| `/static/**` | WebMvcConfigurer | Ant |

### 路径走私测试矩阵

| 原始路径 | 走私Payload | 测试结果 | 风险等级 |
|----------|-------------|----------|----------|
| `/api/v2/**` | `..;/..;/admin/privilege` | 可越权访问 | HIGH |
| `/api/v2/**` | `/..%252f..%252fpasswd` | 可访问敏感文件 | CRITICAL |
```