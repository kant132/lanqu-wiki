# 反序列化审计分支

## 触发条件

- 标签: `DESERIALIZE`, `READ_OBJECT`
- 优先级: 1（高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| D1 | 反序列化数据是否来自不可信来源？ |
| D2 | 是否使用类型白名单过滤（`ObjectInputFilter`/`SerialKiller`）？ |
| D3 | Fastjson是否开启`safeMode`或配置`autoType`白名单？ |
| D4 | Jackson是否禁用`enableDefaultTyping()`或使用`@JsonTypeInfo`白名单？ |
| D5 | 是否使用安全的替代方案（JSON/Protobuf）？ |
| D6 | Hessian/Kryo/XStream是否配置类型白名单？ |

## 危险Sink清单

```java
// Java原生
ObjectInputStream.readObject()
ObjectInputStream.readUnshared()
XMLDecoder.readObject()

// Fastjson
JSON.parseObject(input)
JSON.parseObject(input, Feature.SupportNonPublicField)
// autoType未禁用时: {"@type":"java.lang.Runtime"}

// Jackson
ObjectMapper.enableDefaultTyping()
ObjectMapper.enableDefaultTyping(ObjectMapper.DefaultTyping.NON_FINAL)
@JsonTypeInfo(use = JsonTypeInfo.Id.CLASS)

// 其他
XStream.fromXML(input)
Hessian2Input.readObject()
Kryo.readObject(input, clazz)
Yaml.load(input)  // SnakeYAML
```

## 审计流程

```
1. 定位反序列化Sink点
2. 识别使用的反序列化库
3. 反向追踪数据来源
4. 检查是否存在类型过滤
5. 检查库版本是否存在已知Gadget
6. 使用LSP确认数据来源可控性
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- 反序列化数据来自消息队列/缓存 → 追踪数据写入来源
- 反序列化数据来自数据库BLOB → 检查写入时是否可信

## 输出格式

```json
{
  "branch": "deserialization",
  "findings": [
    {
      "type": "反序列化RCE",
      "severity": "CRITICAL",
      "sink": "CacheService.java:88",
      "source": "Redis缓存数据",
      "evidence": "ObjectInputStream.readObject()",
      "sanitization": "无ObjectInputFilter，无类型白名单",
      "poc": "构造CommonsCollections Gadget链写入Redis",
      "gadget_chains": ["CommonsCollections6", "CB1"]
    }
  ]
}
```
