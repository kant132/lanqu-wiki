# SQL注入审计分支

## 触发条件

- 标签: `SQL_CONCAT`, `SQL_STATEMENT`
- 优先级: 1（高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| S1 | 是否使用 `PreparedStatement` 参数化查询？ |
| S2 | MyBatis 是否使用 `#{}` 而非 `${}`？ |
| S3 | Hibernate/JPA 是否使用 `setParameter()` 而非字符串拼接？ |
| S4 | 动态表名/列名是否使用白名单验证？ |
| S5 | `ORDER BY` 动态字段是否使用枚举映射？ |
| S6 | `LIKE` 查询是否转义 `%` 和 `_` 通配符？ |
| S7 | `LIMIT/OFFSET` 是否强制类型转换为整数？ |
| S8 | 存储过程调用是否使用参数绑定？ |

## 危险Sink清单

```java
// JDBC
Statement.executeQuery(sql)
Statement.executeUpdate(sql)
Connection.prepareStatement(sql)  // 若sql已拼接

// MyBatis
${param}  // XML中
@Select("SELECT * FROM users WHERE id = ${id}")

// Hibernate
session.createQuery("FROM User WHERE name = '" + name + "'")
session.createSQLQuery(sql)

// Spring JDBC
jdbcTemplate.query(sql, ...)  // 若sql已拼接
namedParameterJdbcTemplate.query(sql, ...)  // 若sql已拼接
```

## 审计流程

```
1. 定位Sink点（SQL执行语句）
2. 反向追踪SQL字符串构建过程
3. 检查是否存在参数化查询
4. 若存在拼接，追踪拼接变量来源
5. 使用LSP确认变量是否来自外部输入
6. 检查是否存在净化措施（白名单/类型转换）
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- SQL字符串来自Service层方法参数 → 请求追踪Service调用者
- SQL字符串来自配置/常量 → 标记为FALSE_POSITIVE

## 输出格式

```json
{
  "branch": "sqli",
  "findings": [
    {
      "type": "SQL注入",
      "severity": "CRITICAL",
      "sink": "UserMapper.java:45",
      "source": "UserController.java:28 @RequestParam",
      "evidence": "SELECT * FROM users WHERE name = '${name}'",
      "sanitization": "无",
      "poc": "GET /api/users?name=' OR '1'='1"
    }
  ]
}
```
