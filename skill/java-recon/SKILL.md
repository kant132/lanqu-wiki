---
name: java-recon
description: Java 项目侦察与资产台账建立。当需要识别 Java 项目的技术栈、路由引擎、Filter/Interceptor 清单时加载。Use when scanning Java project structure, identifying frameworks, filters, interceptors, or building asset inventory.
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Phase 1: 项目分析初始化与组件拓扑识别

## 输入

- 项目根路径

## 输出

- Asset-Inventory JSON（符合 `shared-contracts.md` 协议）

## 门禁断言清单

| 断言 | 含义 | 触发条件 |
|------|------|----------|
| C1 | 依赖完整性 | pom.xml 或 build.gradle 存在且可解析 |
| C2 | 全引擎组件识别 | 扫描并精准记录所有路由引擎（Spring WebMVC, JAX-RS/Jersey, Struts2, Native Servlet, Dubbo/gRPC） |
| C3 | 资产台账已建立 | Filters.size() + Interceptors.size() >= 0（若为 0，标记 WARN-NO-GUARD 并跳过 Phase 2/3，直接进入 Phase 4/5） |
| C4 | 组件注册全覆盖 | 交叉检索XML配置、类注解及配置类，建立资产总表 |
| C5 | 版本号精准感知 | 识别核心框架版本，为后续特定版本行为提供判定基准 |

## 执行流程

### Step 1: 构建文件解析（C1, C5）

```
1. 定位 pom.xml 或 build.gradle
2. 提取核心依赖及版本号
3. 识别框架类型：
   - spring-boot-starter-web → Spring MVC
   - spring-boot-starter-webflux → Spring WebFlux
   - struts2-core → Struts2
   - jersey-server → JAX-RS
   - dubbo → Dubbo RPC
4. 若构建文件不存在 → 触发 ERR-NO-BUILD
```

### Step 2: 路由引擎识别（C2）

针对每种引擎执行特征扫描：

| 引擎 | 扫描目标 |
|------|----------|
| Spring MVC | `@Controller`, `@RestController`, `@RequestMapping` |
| JAX-RS | `@Path`, `@GET`, `@POST` |
| Struts2 | `struts.xml`, `@Action` |
| Native Servlet | `@WebServlet`, `web.xml <servlet>` |
| Dubbo | `@DubboService`, `@DubboReference` |

### Step 3: Filter 资产提取

```
扫描目标：
- @WebFilter 注解类
- web.xml <filter> + <filter-mapping>
- FilterRegistrationBean 注册
- Spring Security FilterChain 配置

提取字段：class, url_patterns, order, dispatcher_types
```

### Step 4: Interceptor 资产提取

```
扫描目标：
- HandlerInterceptor 实现类
- WebMvcConfigurer.addInterceptors()
- XML <mvc:interceptors>

提取字段：class, include_patterns, exclude_patterns
```

### Step 5: 配置源交叉验证（C4）

```
交叉检索：
- Java Config 类（@Configuration）
- XML 配置文件
- application.yml / application.properties
- 注解扫描

确保每个组件至少在一个配置源中被注册。
```

## 强制输出模板

> 详细输出模板见 [`references/phase1-init-output.md`](references/phase1-init-output.md)

## 输出示例

```json
{
  "project_meta": {
    "framework": "Spring Boot",
    "version": "3.2.0",
    "build_tool": "Maven"
  },
  "engines": ["Spring MVC"],
  "filters": [
    {
      "id": "FILTER-001",
      "class": "com.example.AuthFilter",
      "url_patterns": ["/api/*"],
      "order": 1
    }
  ],
  "interceptors": [
    {
      "id": "INTC-001",
      "class": "com.example.LoginInterceptor",
      "include_patterns": ["/**"],
      "exclude_patterns": ["/login", "/static/**"]
    }
  ],
  "config_sources": ["WebMvcConfig.java", "application.yml"],
  "warnings": []
}
```
