# LDAP注入审计分支

## 触发条件

- 标签: `LDAP_SEARCH`
- 优先级: 2（中高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| LDAP1 | LDAP查询过滤器是否使用参数化？ |
| LDAP2 | 是否对特殊字符进行转义（`()`, `*`, `\`, `NUL`）？ |
| LDAP3 | 是否使用`SearchControls`限制返回属性？ |
| LDAP4 | 是否限制搜索结果数量？ |
| LDAP5 | DN构造是否使用转义？ |

## 危险Sink清单

```java
// JNDI
DirContext.search(baseDN, filter, searchControls)
// 若filter拼接: "(&(uid=" + userInput + ")(userPassword=*))"

// Spring LDAP
LdapTemplate.search(query)
// 若使用硬编码过滤器拼接

// UnboundID
LDAPConnection.search(baseDN, SearchScope.SUB, filter)
```

## LDAP特殊字符转义

```java
// 过滤器特殊字符: ( ) \ * NUL
// DN特殊字符: , + " \ < > ; = # 以及前导/尾随空格

// 安全做法
String safeFilter = LdapEncoder.filterEncode(userInput);
DirContext.search(baseDN, safeFilter, controls);
```

## 审计流程

```
1. 定位LDAP查询Sink点
2. 检查过滤器构建方式
3. 反向追踪过滤器参数来源
4. 检查是否存在转义处理
5. 使用LSP确认参数可控性
6. 生成漏洞报告或标记为安全
```

## 输出格式

```json
{
  "branch": "ldap",
  "findings": [
    {
      "type": "LDAP注入",
      "severity": "HIGH",
      "sink": "LdapAuthService.java:38",
      "source": "LoginController.java:15 @RequestParam",
      "evidence": "ctx.search(baseDN, \"(uid=\" + username + \")\", controls)",
      "sanitization": "无LdapEncoder转义",
      "poc": "username=*)(uid=*))(|(uid=*"
    }
  ]
}
```
