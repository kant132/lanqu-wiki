---
name: java-interceptor-audit
description: Java Interceptor 安全审计。当需要审计 Spring HandlerInterceptor、Struts2 Interceptor 的路径配置、放行策略、路径走私风险时加载。Use when auditing Java interceptors for path configuration, whitelist bypass, path smuggling, or static resource traversal.
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Phase 3: 拦截器核心审计及静态资源专项审计

## 输入

- Asset-Inventory JSON（来自 Phase 1 的 interceptors 列表）
- 项目根路径

## 输出

- Phase-Result JSON（符合 `shared-contracts.md` 协议）

## 配置层与路由层横向断言（I1-I7）

| 断言 | 检查项 | 说明 |
|------|--------|------|
| I1 | 拦截路径覆盖 | `addPathPatterns` 是否使用全局通配 `/`？ |
| I2 | 白名单过宽风险 | `excludePathPatterns` 是否存在模糊通配放行？ |
| I3 | 静态资源放行 | 是否通过 `!(handler instanceof HandlerMethod)` 盲目放行非 Controller 请求？ |
| I4 | 宿主框架路由配置 | 是否更改了底层的路径辅助器（如 Spring `UrlPathHelper`）的分号截断及斜杠匹配策略？ |
| I5 | 尾部斜杠不一致性 | 项目对应的框架版本在处理尾部斜杠时，拦截器与路由层是否存在解析脱节？若感知到 Spring Boot 3.x / Spring Framework 6.x，必须断言其默认弃用 TrailingSlashMatch 的特性 |
| I6 | 注解符号追踪 | 拦截器内部若使用自定义特权注解（如 `@Anonymous`），必须通过 LSP 追踪其解析逻辑 |
| I7 | 配置层加载状态 | 该拦截组件对应的配置类或配置 XML 是否被 Spring/相关引擎正常扫描和消费？ |

## 静态资源/全局放行专项审计（S1-S4）

| 断言 | 检查项 | 说明 |
|------|--------|------|
| S1 | 放行路径枚举 | 扫描所有 `excludePathPatterns`, `security.matcher`, `antMatchers` 配置，枚举所有放行路径 |
| S2 | 路径走私断言 | 针对每个放行路径，执行"路径走私"断言：是否可以使用 `..;/`、`%252e%252e/` 等技巧访问其上层受保护目录？ |
| S3 | 通配符绕过 | 针对 `/**` 通配符，断言其后是否存在 `//` 或 `/./` 绕过可能性？ |
| S4 | 目录穿越 | 针对静态资源目录，断言是否可以通过 `../../../WEB-INF/web.xml` 进行目录穿越？ |

## 执行流程

### Step 1: 加载 Interceptor 清单

从 Asset-Inventory 提取 interceptors 列表，若为空则返回 N/A。

### Step 2: 执行顺序分析

```
提取所有 Interceptor 的执行顺序：
  - WebMvcConfigurer.addInterceptors() 中的 registry.addInterceptor() 调用顺序
  - @Order 注解或 Ordered 接口的 order 值
  - InterceptorRegistration.order() 显式设置
  - Spring Security Filter 与 MVC Interceptor 的相对执行关系

输出 Interceptor 执行链：
  InterceptorChain = [Interceptor1(order=1) → Interceptor2(order=2) → ... → InterceptorN(order=N)]

对每个 Interceptor 记录：
  - 执行位置（第几个）
  - 包含路径模式（addPathPatterns）
  - 排除路径模式（excludePathPatterns）
  - preHandle 返回值（true=放行 / false=拦截）

注意：Spring 请求处理顺序为：
  Filter Chain → DispatcherServlet → HandlerInterceptor.preHandle() → Controller → HandlerInterceptor.postHandle()
  即 Filter 始终在 Interceptor 之前执行
```

### Step 3: 逐 Interceptor 断言（I1-I7）

```
for each interceptor in inventory.interceptors:
    read interceptor source file
    read associated config class/XML
    for each assertion in [I1..I7]:
        evaluate assertion
        record result
```

### Step 4: 静态资源专项（S1-S4）

```
enumerate all exclude patterns
for each pattern:
    test path smuggling vectors
    test wildcard bypass
    test directory traversal
```

### Step 5: 漏洞可达性评估

```
对每个 FAIL 断言的漏洞，评估其实际可达性：

1. Filter 层前置拦截分析：
   - 检查 Phase 2 的 Filter 执行链
   - 若 Filter 已在 Interceptor 之前拦截了相关请求，则 Interceptor 漏洞不可达
   - 例如：Interceptor 白名单过宽，但 Filter 层已正确限制该路径

2. Interceptor 链内前置分析：
   - 检查该 Interceptor 之前的其他 Interceptor
   - 若前置 Interceptor 的 preHandle 返回 false 拦截了相同路径，则漏洞不可达

3. 路径模式交叉验证：
   - 漏洞影响的 URL 模式是否被其他 Interceptor 的 addPathPatterns 覆盖
   - excludePathPatterns 放行的路径是否被其他 Interceptor 捕获

4. Spring Security 层补偿分析：
   - SecurityFilterChain 的 authorizeHttpRequests 是否已限制该路径
   - @PreAuthorize 注解是否在 Controller 层提供了额外保护

可达性等级：
  - REACHABLE: 漏洞可被实际触发，无前置拦截或后置补偿
  - PARTIALLY_REACHABLE: 部分场景可达，存在条件限制
  - UNREACHABLE: 被前置 Filter/Interceptor 拦截或后置补偿，实际不可触发

严重度调整规则：
  - REACHABLE: 保持原严重度
  - PARTIALLY_REACHABLE: 严重度降一级
  - UNREACHABLE: 严重度降为 INFO（提示级别），仅作为代码质量提示
```

### Step 6: 熔断标记

若任一 Interceptor 的 I2/I3/S2 为 FAIL **且可达性为 REACHABLE 或 PARTIALLY_REACHABLE**，生成 `interceptor_bypassed` 熔断标记。

## 强制输出模板

> 详细输出模板见 [`references/phase3-interceptor-output.md`](references/phase3-interceptor-output.md)

## 输出示例

```json
{
  "phase": "Phase 3",
  "assertions": [
    {
      "id": "I2",
      "target": "INTC-001",
      "status": "FAIL",
      "evidence": "WebMvcConfig.java:28",
      "detail": "excludePathPatterns(\"/api/public/**\") 通配过宽"
    },
    {
      "id": "S2",
      "target": "INTC-001",
      "status": "FAIL",
      "evidence": "WebMvcConfig.java:28",
      "detail": "/api/public/..;/admin 可路径走私访问受保护目录"
    }
  ],
  "circuit_breakers": [
    {
      "type": "interceptor_bypassed",
      "target": "INTC-001",
      "affected_paths": ["/api/public/**"]
    }
  ]
}
```
