# Phase 5 全量路由资产提取规则

## 执行流程

子 Agent 必须激活针对不同组件的全资产扫描算子，严格遵循"引擎感知 → 强制遍历 → 静态解析"的流程。

---

## (1) Spring 算子

**扫描范围**: 所有标注 `@Controller` 或 `@RestController` 的类

**继承拓扑溯源**: 向上递归解析类的父类和接口，直到抵达 Object 或框架基类

**路径拼接**: 
- 提取类级注解 `@RequestMapping` 的 value/path 属性
- 提取方法级注解 `@RequestMapping`、`@GetMapping` 等的 value/path 属性

**参数提取**: 处理以下注解
- `@PathVariable`
- `@RequestParam`
- `@RequestBody`
- `@RequestHeader`
- `@CookieValue`

---

## (2) JAX-RS 算子

**扫描范围**: 所有标注 `@Path` 的资源类

**HTTP方法识别**: 强制盘点以下注解的方法
- `@GET`、`@POST`、`@PUT`、`@DELETE`
- `@HEAD`、`@OPTIONS`、`@PATCH`

**正则边界提取**: 强力拉取 `@Path` 中内嵌的正则表达式

示例: `@Path("/users/{id: \\d+}")`

**参数提取**:
- `@PathParam`、`@QueryParam`、`@HeaderParam`
- `@CookieParam`、`@FormParam`、`@MatrixParam`
- `@Context`

---

## (3) Servlet 算子

**扫描范围**: 
- 解析 `web.xml` 中的 `<servlet>` 与 `<servlet-mapping>` 元素
- 扫描所有标注 `@WebServlet` 的类

**路径规范**: `<url-pattern>` 可能包含通配符（如 `/*`、`/action/*`、`*.do`），原样记录为路由模式

**方法与参数**: 
- 依据 HttpServlet 接口约定关联 GET/POST 方法
- 参数提取依赖 `request.getParameter` 调用

---

## (4) RPC 算子（Dubbo / gRPC）

**扫描范围**: 
- Dubbo: `@DubboService` 或实现 `com.alibaba.dubbo.*` 接口的类
- gRPC: 继承自 `XXXGrpc.XXXImplBase` 的类

**端点建模**: 格式为 `RPC_CALL:<InterfaceFullName>:<MethodName>`

**参数提取**: 方法形参即为暴露的输入参数，记录其名称、类型全限定名及参数位置
