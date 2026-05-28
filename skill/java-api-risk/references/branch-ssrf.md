# SSRF审计分支

## 触发条件

- 标签: `HTTP_CLIENT`, `URL_OPEN`
- 优先级: 2（中高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| SSRF1 | URL是否来自用户可控输入？ |
| SSRF2 | 是否校验URL的协议（仅允许http/https）？ |
| SSRF3 | 是否校验URL的域名白名单？ |
| SSRF4 | 是否阻止内网IP（`10.x`, `172.16-31.x`, `192.168.x`, `127.x`, `169.254.x`）？ |
| SSRF5 | 是否阻止DNS重绑定攻击（解析后二次校验IP）？ |
| SSRF6 | 是否阻止URL重定向跟随？ |
| SSRF7 | 是否阻止非HTTP协议（`file://`, `gopher://`, `dict://`）？ |

## 危险Sink清单

```java
// Spring
RestTemplate.getForObject(url, ...)
RestTemplate.exchange(url, ...)
WebClient.get().uri(url)

// Apache HttpClient
HttpClient.execute(new HttpGet(url))
HttpClients.custom().build().execute(request)

// JDK
new URL(url).openConnection()
new URL(url).openStream()
HttpURLConnection.connect()

// OkHttp
OkHttpClient.newCall(new Request.Builder().url(url).build())
```

## 审计流程

```
1. 定位HTTP请求Sink点
2. 反向追踪URL参数来源
3. 检查是否存在URL校验/白名单
4. 检查是否阻止内网IP
5. 检查是否处理重定向
6. 使用LSP确认URL可控性
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- URL来自配置中心/数据库 → 检查配置写入权限
- URL部分可控（域名固定但路径可控） → 评估危害等级

## 输出格式

```json
{
  "branch": "ssrf",
  "findings": [
    {
      "type": "SSRF",
      "severity": "HIGH",
      "sink": "ProxyService.java:56",
      "source": "ProxyController.java:22 @RequestParam",
      "evidence": "restTemplate.getForObject(targetUrl, String.class)",
      "sanitization": "无域名白名单，无内网IP过滤",
      "poc": "GET /api/proxy?url=http://169.254.169.254/latest/meta-data/"
    }
  ]
}
```
