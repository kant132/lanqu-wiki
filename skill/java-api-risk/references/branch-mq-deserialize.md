# 消息队列审计分支

## 触发条件

- 标签: `KAFKA_CONSUMER`, `KAFKA_PRODUCER`, `RABBITMQ`, `ROCKETMQ_DESER`, `ACTIVEMQ`, `PULSAR`
- 优先级: 2（中高危）

## 审计检查点

### Kafka

| 检查项 | 说明 |
|--------|------|
| KF1 | Consumer 反序列化是否使用安全 Deserializer？ |
| KF2 | 是否存在自定义 Deserializer 反序列化漏洞？ |
| KF3 | Producer 是否校验消息格式？ |
| KF4 | 是否启用 SASL/SSL 认证？ |
| KF5 | Topic 是否存在未授权访问？ |
| KF6 | 是否存在消息重放攻击风险？ |

### RabbitMQ

| 检查项 | 说明 |
|--------|------|
| RM1 | 消息反序列化是否安全（Java Serialization vs JSON）？ |
| RM2 | 是否存在 Spring AMQP 反序列化漏洞？ |
| RM3 | 是否启用用户认证和权限控制？ |
| RM4 | Management API 是否暴露（默认 15672）？ |
| RM5 | 是否存在 Shovel/Federation 配置注入？ |

### RocketMQ

| 检查项 | 说明 |
|--------|------|
| RQ1 | 是否存在 RocketMQ 反序列化漏洞（Hessian2）？ |
| RQ2 | NameServer 是否启用认证？ |
| RQ3 | 是否存在 Topic 未授权访问？ |
| RQ4 | 是否存在消息过滤表达式注入？ |
| RQ5 | Remoting 协议是否存在 RCE？ |

### ActiveMQ

| 检查项 | 说明 |
|--------|------|
| AM1 | 是否存在 OpenWire 协议反序列化漏洞（CVE-2023-46604）？ |
| AM2 | 是否存在 Stomp 协议注入？ |
| AM3 | Web Console 是否暴露（默认 8161）？ |
| AM4 | 是否存在默认凭证（admin/admin）？ |

## 危险模式

```java
// Kafka 不安全反序列化
props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, 
    "org.apache.kafka.common.serialization.ByteArrayDeserializer");
// 若后续使用 ObjectInputStream 反序列化 → RCE

// Spring AMQP 反序列化
@Bean
public MessageConverter messageConverter() {
    return new SimpleMessageConverter();  // 默认使用 Java Serialization
}
// 攻击者发送序列化恶意对象 → RCE

// RocketMQ Hessian2 反序列化
consumer.setMessageModel(MessageModel.CLUSTERING);
// 默认使用 Hessian2 → 存在已知 Gadget

// ActiveMQ OpenWire 反序列化 (CVE-2023-46604)
// OpenWire 协议命令处理存在反序列化漏洞
// 需要升级至 5.15.16+ / 5.16.7+ / 5.17.6+ / 5.18.3+
```

## 消息队列已知漏洞

| 漏洞 | 说明 |
|------|------|
| CVE-2023-46604 | ActiveMQ OpenWire RCE |
| CVE-2023-33246 | RocketMQ RCE |
| Spring AMQP-502 | Spring AMQP 反序列化 |
| Kafka-4372 | Kafka Consumer 反序列化 |

## 审计流程

```
1. 识别项目使用的消息队列
2. 检查序列化/反序列化配置
3. 检查认证和授权配置
4. 检查管理端口暴露
5. 检查消息过滤表达式
6. 使用 LSP 追踪消息处理链
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- 消息处理逻辑在 Consumer 中 → 请求展开 Consumer 代码
- 序列化配置在外部文件 → 请求读取配置
- 消息来自外部系统 → 追踪消息来源可信性

## 输出格式

```json
{
  "branch": "mq-deserialize",
  "mq_type": "RocketMQ",
  "findings": [
    {
      "type": "RocketMQ Hessian2 反序列化",
      "severity": "CRITICAL",
      "sink": "OrderConsumer.java:45",
      "source": "RocketMQ 消息",
      "evidence": "默认 Hessian2 序列化，未配置白名单",
      "sanitization": "无序列化过滤",
      "poc": "构造 Hessian2 Gadget 发送至 RocketMQ Topic",
      "gadget_chains": ["SpringAbstractBeanFactoryPointcutAdvisor"]
    }
  ]
}
```
