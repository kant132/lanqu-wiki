# 路由提取算子

## Spring MVC 算子

**扫描范围**: 所有标注 `@Controller` 或 `@RestController` 的类

**路径拼接**:
- 提取类级 `@RequestMapping` 的 value/path 属性作为前缀
- 提取方法级 `@RequestMapping`/`@GetMapping`/`@PostMapping` 等的 value/path 属性
- 完整路径 = 类级前缀 + 方法级路径

**参数提取**:
- `@PathVariable` — 路径参数
- `@RequestParam` — 查询参数/表单参数
- `@RequestBody` — 请求体参数
- `@RequestHeader` — 请求头参数
- `@CookieValue` — Cookie 参数

**认证识别**:
- 方法/类上的 `@PreAuthorize`、`@Secured`、`@RolesAllowed`
- 无注解 → 依赖全局 SecurityFilterChain

## JAX-RS 算子

**扫描范围**: 所有标注 `@Path` 的资源类

**HTTP 方法**: `@GET`、`@POST`、`@PUT`、`@DELETE`、`@HEAD`、`@OPTIONS`、`@PATCH`

**正则提取**: `@Path("/users/{id: \\d+}")` 中的正则表达式需保留

**参数**: `@PathParam`、`@QueryParam`、`@HeaderParam`、`@CookieParam`、`@FormParam`、`@Context`

## Servlet 算子

**扫描范围**: `web.xml` 中 `<servlet-mapping>` + `@WebServlet` 注解类

**路径**: `<url-pattern>` 原样记录（含通配符 `/*`、`*.do`）

**参数**: 通过 `request.getParameter`/`request.getInputStream` 调用识别

## RPC 算子

**Dubbo**: `@DubboService` 或实现 Dubbo 接口的类 → 端点格式 `RPC_CALL:<Interface>:<Method>`

**gRPC**: 继承 `XXXGrpc.XXXImplBase` 的类 → 端点格式 `gRPC:<Service>:<Method>`

**参数**: 方法形参即为暴露的输入参数
