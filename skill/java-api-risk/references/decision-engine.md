# 决策引擎规则

## 内置规则

决策引擎根据代码嗅探标签路由到对应审计分支。

### 标签 → 分支映射

| 嗅探标签 | 触发分支 | 优先级 | 分支文件 |
|----------|----------|--------|----------|
| SQL_CONCAT | SQL注入审计 | 1 | `branch-sqli.md` |
| SQL_STATEMENT | SQL注入审计 | 1 | `branch-sqli.md` |
| FILE_PATH | 路径穿越审计 | 2 | `branch-path-traversal.md` |
| FILE_INPUT | 路径穿越审计 | 2 | `branch-path-traversal.md` |
| HTTP_CLIENT | SSRF审计 | 2 | `branch-ssrf.md` |
| URL_OPEN | SSRF审计 | 2 | `branch-ssrf.md` |
| DESERIALIZE | 反序列化审计 | 1 | `branch-deserialization.md` |
| READ_OBJECT | 反序列化审计 | 1 | `branch-deserialization.md` |
| TEMPLATE_RENDER | SSTI模板注入审计 | 1 | `branch-ssti.md` |
| TH_UTEXT | SSTI模板注入审计 | 1 | `branch-ssti.md` |
| FREEMARKER_NEW | SSTI模板注入审计 | 1 | `branch-ssti.md` |
| VELOCITY_REFLECT | SSTI模板注入审计 | 1 | `branch-ssti.md` |
| EXPRESSION_PARSE | 表达式注入审计 | 1 | `branch-expression.md` |
| OGNL | 表达式注入审计 | 1 | `branch-expression.md` |
| EL_INJECT | 表达式注入审计 | 1 | `branch-expression.md` |
| MVEL_EVAL | 表达式注入审计 | 1 | `branch-expression.md` |
| BEANSHELL | 表达式注入审计 | 1 | `branch-expression.md` |
| GROOVY_EVAL | 表达式注入审计 | 1 | `branch-expression.md` |
| NASHORN | 表达式注入审计 | 1 | `branch-expression.md` |
| JNDI_LOOKUP | JNDI注入审计 | 1 | `branch-jndi.md` |
| XXE_PARSE | XXE审计 | 1 | `branch-xxe.md` |
| FILE_UPLOAD | 文件上传审计 | 2 | `branch-file-upload.md` |
| LDAP_SEARCH | LDAP注入审计 | 2 | `branch-ldap.md` |
| AUTH_MISSING | IDOR/越权审计 | 3 | `branch-idor.md` |
| NO_ROLE | IDOR/越权审计 | 3 | `branch-idor.md` |
| CRYPTO_WEAK | 密码学审计 | 3 | `branch-crypto.md` |
| HARDCODED_KEY | 密码学审计 | 3 | `branch-crypto.md` |
| COMMAND_EXEC | 命令注入审计 | 1 | `branch-command.md` |
| PROCESS_BUILDER | 命令注入审计 | 1 | `branch-command.md` |
| REDIRECT         | 重定向审计     | 3   | `branch-redirect.md`        |
| FORWARD          | 重定向审计     | 3   | `branch-redirect.md`        |
| OAUTH2           | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| SAML             | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| CAS_TICKET       | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| SHIRO            | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| SPRING_SECURITY  | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| JWT_ADVANCED     | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| OIDC             | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| KERBEROS         | 认证协议审计    | 1   | `branch-auth-protocol.md`   |
| DUBBO_SERVICE    | RPC框架审计    | 1   | `branch-rpc-framework.md`   |
| DUBBO_CONSUMER   | RPC框架审计    | 1   | `branch-rpc-framework.md`   |
| THRIFT           | RPC框架审计    | 1   | `branch-rpc-framework.md`   |
| GRPC_SERVICE     | RPC框架审计    | 1   | `branch-rpc-framework.md`   |
| HSF              | RPC框架审计    | 1   | `branch-rpc-framework.md`   |
| MOTAN            | RPC框架审计    | 1   | `branch-rpc-framework.md`   |
| SOFA_RPC         | RPC框架审计    | 1   | `branch-rpc-framework.md`   |
| JDBC_URL         | 数据库协议审计   | 1   | `branch-db-protocol.md`     |
| MYSQL_DESER      | 数据库协议审计   | 1   | `branch-db-protocol.md`     |
| POSTGRES_COPY    | 数据库协议审计   | 1   | `branch-db-protocol.md`     |
| REDIS_PROTO      | 数据库协议审计   | 1   | `branch-db-protocol.md`     |
| MONGO_NOSQL      | 数据库协议审计   | 1   | `branch-db-protocol.md`     |
| ELASTICSEARCH_INJECT | 数据库协议审计 | 1 | `branch-db-protocol.md`   |
| KAFKA_CONSUMER   | 消息队列审计    | 2   | `branch-mq-deserialize.md`  |
| KAFKA_PRODUCER   | 消息队列审计    | 2   | `branch-mq-deserialize.md`  |
| RABBITMQ         | 消息队列审计    | 2   | `branch-mq-deserialize.md`  |
| ROCKETMQ_DESER   | 消息队列审计    | 2   | `branch-mq-deserialize.md`  |
| ACTIVEMQ         | 消息队列审计    | 2   | `branch-mq-deserialize.md`  |
| PULSAR           | 消息队列审计    | 2   | `branch-mq-deserialize.md`  |
| REDIS_DESER      | 缓存注入审计    | 2   | `branch-cache-inject.md`    |
| REDIS_COMMAND    | 缓存注入审计    | 2   | `branch-cache-inject.md`    |
| MEMCACHED        | 缓存注入审计    | 2   | `branch-cache-inject.md`    |
| CACHE_POISON     | 缓存注入审计    | 2   | `branch-cache-inject.md`    |
| EHCACHE          | 缓存注入审计    | 2   | `branch-cache-inject.md`    |
| CAFFEINE         | 缓存注入审计    | 2   | `branch-cache-inject.md`    |

### 优先级说明

| 优先级 | 含义 |
|--------|------|
| 1 | 高危，必须立即审计 |
| 2 | 中高危，优先审计 |
| 3 | 中危，按序审计 |
| 4 | 低危，选择性审计 |

## 标签检测模式

### 代码嗅探正则

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
OAUTH2:            @EnableOAuth2Sso|OAuth2RestTemplate|AuthorizationCodeResourceDetails|redirect_uri
SAML:              SAMLMessageDecoder|SAMLAuthenticationProvider|opensaml|spring-security-saml
CAS_TICKET:        CasAuthenticationProvider|Cas20ServiceTicketValidator|AssertionImpl
SHIRO:             org\.apache\.shiro|SecurityManager|RememberMeManager|CookieRememberMeManager
SPRING_SECURITY:   SecurityFilterChain|WebSecurityConfigurerAdapter|HttpSecurity|@EnableWebSecurity
JWT_ADVANCED:      Jwts\.parser|JWT\.decode|JWKSet|jwks_uri|RS256|HS256
OIDC:              OidcUserService|OidcIdTokenDecoder|OidcClientInitiatedLogoutSuccessHandler
KERBEROS:          KerberosServiceAuthenticationProvider|SpnegoEntryPoint|GSSContext
DUBBO_SERVICE:     @DubboService|@Service.*dubbo|DubboService|ExportAsync
DUBBO_CONSUMER:    @DubboReference|@Reference|ReferenceConfig|GenericService
THRIFT:            TProcessor|TServerSocket|TBinaryProtocol|TCompactProtocol
GRPC_SERVICE:      extends.*Grpc\..*ImplBase|@GrpcService|ManagedChannel|ServerBuilder
HSF:               @HSFProvider|@HSFConsumer|HSFSpringProviderBean|HSFSpringConsumerBean
MOTAN:             @MotanService|@MotanReferer|MotanServiceConfig
SOFA_RPC:          @SofaService|@SofaReference|SofaServiceBinding
JDBC_URL:          DriverManager\.getConnection|DataSource\.setUrl|jdbc:|HikariConfig.*jdbcUrl
MYSQL_DESER:       autoDeserialize|allowLoadLocalInfile|queryInterceptors|mysql-connector-java
POSTGRES_COPY:     COPY.*TO|COPY.*FROM|lo_import|lo_export|PROGRAM
REDIS_PROTO:       Jedis|Lettuce|RedisTemplate|Redisson|jedis\.get|jedis\.set
MONGO_NOSQL:       MongoCollection|MongoTemplate|DBObject|\$gt|\$ne|\$where|BasicDBObject
ELASTICSEARCH_INJECT: RestHighLevelClient|SearchSourceBuilder|QueryBuilder|_search
KAFKA_CONSUMER:    @KafkaListener|KafkaConsumer|ConsumerConfig|Deserializer
KAFKA_PRODUCER:    KafkaTemplate|KafkaProducer|ProducerConfig
RABBITMQ:          @RabbitListener|RabbitTemplate|SimpleMessageConverter|ConnectionFactory
ROCKETMQ_DESER:    @RocketMQMessageListener|DefaultMQPushConsumer|MessageListenerConcurrently
ACTIVEMQ:          ActiveMQConnectionFactory|JmsTemplate|@JmsListener|OpenWire
PULSAR:            PulsarClient|Consumer|Producer|MessageListener
REDIS_DESER:       JdkSerializationRedisSerializer|GenericJackson2JsonRedisSerializer|RedisSerializer
REDIS_COMMAND:     jedis\.eval|jedis\.configSet|jedis\.slaveof|jedis\.moduleLoad
MEMCACHED:         MemcachedClient|SpyMemcached|XMemcached
CACHE_POISON:      @Cacheable|@CachePut|CacheManager|Ehcache|Caffeine
EHCACHE:           EhcacheManager|CacheConfiguration|EhcacheCachingProvider
CAFFEINE:          Caffeine\.newBuilder|CaffeineCache|CaffeineCacheManager
```

## 扩展接口

### 用户自定义规则

项目根目录 `.audit-extensions/rules.json`:

```json
{
  "custom_rules": [
    {
      "name": "规则名称",
      "trigger_tags": ["TAG_NAME"],
      "branch_file": ".audit-extensions/branch-xxx.md",
      "priority": 1
    }
  ],
  "tag_detectors": [
    {
      "tag": "TAG_NAME",
      "pattern": "正则表达式",
      "description": "检测说明"
    }
  ]
}
```

### 分支文件格式

```markdown
# 分支名称

## 触发条件
- 标签: TAG_NAME

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| ... | ... |

## 输出格式
...
```

## 决策流程

```
1. 加载内置规则
2. 若存在 .audit-extensions/rules.json:
   a. 加载自定义 tag_detectors
   b. 加载自定义 rules
   c. 合并规则（自定义优先级高于内置）
3. 对每个端点执行嗅探
4. 匹配规则 → 生成分支列表
5. 按优先级排序
6. 若 PARALLEL_BRANCHES=true → 并行执行
7. 否则 → 串行执行
```
