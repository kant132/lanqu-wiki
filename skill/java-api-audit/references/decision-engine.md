# 决策引擎规则

## 标签 → 分支映射

| 嗅探标签 | 触发分支 | 优先级 |
|----------|----------|--------|
| SQL_CONCAT, SQL_STATEMENT | SQL注入审计 | 1 |
| FILE_PATH, FILE_INPUT | 路径穿越审计 | 2 |
| HTTP_CLIENT, URL_OPEN | SSRF审计 | 2 |
| DESERIALIZE, READ_OBJECT | 反序列化审计 | 1 |
| TEMPLATE_RENDER, TH_UTEXT, FREEMARKER_NEW, VELOCITY_REFLECT | SSTI审计 | 1 |
| EXPRESSION_PARSE, OGNL, EL_INJECT, MVEL_EVAL, BEANSHELL, GROOVY_EVAL, NASHORN | 表达式注入审计 | 1 |
| JNDI_LOOKUP | JNDI注入审计 | 1 |
| XXE_PARSE | XXE审计 | 1 |
| FILE_UPLOAD | 文件上传审计 | 2 |
| LDAP_SEARCH | LDAP注入审计 | 2 |
| AUTH_MISSING, NO_ROLE | IDOR/越权审计 | 3 |
| CRYPTO_WEAK, HARDCODED_KEY | 密码学审计 | 3 |
| COMMAND_EXEC, PROCESS_BUILDER | 命令注入审计 | 1 |
| REDIRECT, FORWARD | 重定向审计 | 3 |

## 标签检测模式

```
SQL_CONCAT:        Statement|createQuery|"\$\{"
SQL_STATEMENT:     createStatement|executeQuery|executeUpdate
FILE_PATH:         new File|FileInputStream|Paths\.get|FileOutputStream
FILE_INPUT:        MultipartFile|getOriginalFilename
HTTP_CLIENT:       RestTemplate|HttpClient|WebClient|OkHttp
URL_OPEN:          URL\.openConnection|HttpURLConnection
DESERIALIZE:       readObject|parseObject|enableDefaultTyping|fromXML
READ_OBJECT:       ObjectInputStream|XMLDecoder
TEMPLATE_RENDER:   getTemplate|VelocityEngine|freemarker\.template|SpringTemplateEngine
TH_UTEXT:          th:utext|\#set.*\+
FREEMARKER_NEW:    \?new\(\)|freemarker\.template\.utility|ObjectConstructor|Execute
VELOCITY_REFLECT:  #set.*Class\.forName|#set.*getMethod|#set.*invoke
EXPRESSION_PARSE:  parseExpression|SpelExpressionParser|StandardEvaluationContext
OGNL:              OgnlUtil|ValueStack|findValue|Ognl\.getValue
EL_INJECT:         ExpressionFactory|ValueExpression|MethodExpression|createValueExpression
MVEL_EVAL:         MVEL\.eval|MVEL\.compileExpression|ParserContext
BEANSHELL:         bsh\.Interpreter|Interpreter\.eval|bsh\.Eval
GROOVY_EVAL:       Eval\.me|GroovyShell|GroovyClassLoader|GroovyScriptEngine
NASHORN:           ScriptEngine|NashornScriptEngine|getEngineByName.*javascript
JNDI_LOOKUP:       InitialContext\.lookup|JndiTemplate\.lookup|ctx\.lookup
XXE_PARSE:         DocumentBuilderFactory|SAXParser|XMLReader|TransformerFactory|XMLInputFactory
FILE_UPLOAD:       MultipartFile|CommonsMultipartResolver|StandardServletMultipartResolver
LDAP_SEARCH:       DirContext\.search|LdapTemplate|SearchControls|NamingEnumeration
AUTH_MISSING:      无@PreAuthorize且无@Secured且无hasRole
NO_ROLE:           @PermitAll|permitAll\(\)|anonymous
CRYPTO_WEAK:       DES|MD5|SHA1|ECB|java\.util\.Random
HARDCODED_KEY:     password\s*=\s*"|secret\s*=\s*"|apiKey\s*=\s*"
COMMAND_EXEC:      Runtime\.exec|ProcessBuilder
REDIRECT:          sendRedirect|RedirectView|forward
```

## 优先级说明

| 优先级 | 含义 |
|--------|------|
| 1 | 高危，必须立即审计 |
| 2 | 中高危，优先审计 |
| 3 | 中危，按序审计 |

## 决策流程

```
1. 对每个端点的 Controller + Service 方法体执行代码嗅探
2. 匹配标签 → 生成分支列表
3. 按优先级排序
4. 串行执行各分支审计
5. 每个分支输出: 漏洞确认 / 无发现 / 需更多信息
```
