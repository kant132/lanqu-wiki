# IDOR/越权审计分支

## 触发条件

- 标签: `AUTH_MISSING`, `NO_ROLE`
- 优先级: 3（中危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| IDOR1 | 资源标识符（userId, orderId等）是否来自当前会话？ |
| IDOR2 | 是否校验当前用户与资源所有者的归属关系？ |
| IDOR3 | 是否存在水平越权（用户A访问用户B数据）？ |
| IDOR4 | 是否存在垂直越权（普通用户访问管理员功能）？ |
| IDOR5 | 批量操作接口是否校验每个资源的权限？ |
| IDOR6 | 导出/下载接口是否校验数据归属？ |

## 危险模式

```java
// 水平越权
@GetMapping("/api/orders/{orderId}")
public Order getOrder(@PathVariable Long orderId) {
    return orderService.findById(orderId);  // 未校验当前用户是否是订单所有者
}

// 垂直越权
@DeleteMapping("/api/users/{userId}")
public void deleteUser(@PathVariable Long userId) {
    userService.delete(userId);  // 无@PreAuthorize("hasRole('ADMIN')")
}

// 批量越权
@PostMapping("/api/export")
public void export(@RequestBody List<Long> userIds) {
    userService.exportUsers(userIds);  // 未校验每个userId的可见性
}
```

## 审计流程

```
1. 识别资源标识符参数（userId, orderId, fileId等）
2. 检查是否存在鉴权注解
3. 检查业务逻辑中是否有归属关系校验
4. 追踪资源标识符到数据库查询
5. 确认查询条件是否包含当前用户ID
6. 使用LSP追踪完整调用链
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- 资源标识符经过中间转换（加密ID、UUID映射） → 追踪转换逻辑
- 权限校验在AOP/拦截器中 → 请求展开AOP逻辑

## 输出格式

```json
{
  "branch": "idor",
  "findings": [
    {
      "type": "水平越权 (IDOR)",
      "severity": "HIGH",
      "sink": "OrderService.java:45",
      "source": "OrderController.java:28 @PathVariable orderId",
      "evidence": "orderRepository.findById(orderId)  // 无currentUserId校验",
      "sanitization": "无归属关系校验",
      "poc": "GET /api/orders/123 (当前用户为456，可访问123的订单)"
    }
  ]
}
```
