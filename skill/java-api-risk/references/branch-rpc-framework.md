# RPC框架审计分支

## 触发条件

- 标签: `DUBBO_SERVICE`, `DUBBO_CONSUMER`, `THRIFT`, `GRPC_SERVICE`, `HSF`, `MOTAN`, `SOFA_RPC`
- 优先级: 1（高危）

## 审计检查点

### Dubbo

| 检查项 | 说明 |
|--------|------|
| DU1 | 序列化协议是否安全（Hessian2 存在反序列化漏洞）？ |
| DU2 | 是否配置了序列化白名单（`serialize-check-status=STRICT`）？ |
| DU3 | 是否禁用了 `check=false`（允许调用任意服务）？ |
| DU4 | 是否存在泛化调用（`$invoke`）导致任意方法调用？ |
| DU5 | Telnet 端口是否暴露（默认 22222）？ |
| DU6 | 注册中心是否启用认证？ |
| DU7 | 是否存在 Dubbo QoS 端口暴露（默认 22222）？ |
| DU8 | Filter 链是否存在绕过风险？ |

### Thrift

| 检查项 | 说明 |
|--------|------|
| TH1 | 是否存在协议解析溢出（TBinaryProtocol）？ |
| TH2 | 是否限制了消息大小（防 DoS）？ |
| TH3 | 是否存在 IDL 注入（动态生成 Thrift 调用）？ |
| TH4 | 是否启用了 TLS 加密传输？ |
| TH5 | 是否存在反序列化类型混淆？ |

### gRPC

| 检查项 | 说明 |
|--------|------|
| GR1 | Metadata 是否被信任（可注入认证绕过）？ |
| GR2 | 是否存在 Proto 反射服务暴露（泄露接口定义）？ |
| GR3 | 是否配置了 TLS（mTLS）？ |
| GR4 | 是否存在 Interceptor 绕过（认证 Interceptor 顺序错误）？ |
| GR5 | 是否限制了消息大小（防 DoS）？ |
| GR6 | Server Streaming 是否存在资源泄漏？ |

### HSF / Motan / SOFA-RPC

| 检查项 | 说明 |
|--------|------|
| HS1 | 序列化协议是否安全（Hessian/Hessian2）？ |
| HS2 | 是否配置了服务白名单？ |
| HS3 | 注册中心是否启用认证？ |
| HS4 | 是否存在泛化调用风险？ |
| HS5 | 管理端口是否暴露？ |

## 危险模式

```java
// Dubbo 泛化调用（任意方法调用）
GenericService genericService = (GenericService) referenceConfig.get();
Object result = genericService.$invoke(methodName, paramTypes, args);
// 若 methodName 来自用户输入 → 任意方法调用

// Dubbo Hessian2 反序列化
// 默认使用 Hessian2 序列化，存在已知 Gadget 链
// 需要配置: dubbo.application.serialize-check-status=STRICT

// Thrift 消息大小未限制
TServerSocket serverTransport = new TServerSocket(9090);
// 未设置 maxFrameSize → DoS 风险

// gRPC Metadata 注入
String token = headers.get("authorization");
// 若 Metadata 未校验 → 认证绕过
```

## Dubbo 已知漏洞

| 漏洞 | 说明 |
|------|------|
| CVE-2019-17564 | Dubbo HTTP 协议反序列化 |
| CVE-2020-1948 | Dubbo 反序列化 RCE |
| Dubbo-550 | Hessian2 反序列化（类似 Shiro-550） |
| 泛化调用 RCE | `$invoke` 任意方法调用 |

## 审计流程

```
1. 识别项目使用的 RPC 框架
2. 检查序列化协议配置
3. 检查是否存在泛化调用
4. 检查管理端口暴露
5. 检查注册中心认证
6. 检查 Filter/Interceptor 链
7. 使用 LSP 追踪 RPC 调用链
8. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- RPC 参数经过中间转换 → 请求追踪转换逻辑
- 序列化配置在外部文件 → 请求读取配置
- 泛化调用方法名来自配置 → 追踪配置来源

## 输出格式

```json
{
  "branch": "rpc-framework",
  "framework": "Dubbo",
  "findings": [
    {
      "type": "Dubbo Hessian2 反序列化",
      "severity": "CRITICAL",
      "sink": "Dubbo Provider 端口 20880",
      "source": "网络输入",
      "evidence": "默认 Hessian2 序列化，未配置 serialize-check-status=STRICT",
      "sanitization": "无序列化白名单",
      "poc": "构造 Hessian2 Gadget 链发送至 Dubbo 端口",
      "gadget_chains": ["SpringAbstractBeanFactoryPointcutAdvisor", "JdkDynamicProxy"]
    }
  ]
}
```
