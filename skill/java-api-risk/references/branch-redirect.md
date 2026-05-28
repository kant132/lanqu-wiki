# 重定向审计分支

## 触发条件

- 标签: `REDIRECT`, `FORWARD`
- 优先级: 3（中危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| RD1 | 重定向URL是否来自用户可控输入？ |
| RD2 | 是否校验目标域名白名单？ |
| RD3 | 是否阻止`javascript:`协议？ |
| RD4 | 是否阻止`data:`协议？ |
| RD5 | 是否使用相对路径而非绝对URL？ |
| RD6 | Forward是否可访问内部资源（WEB-INF之外）？ |

## 危险Sink清单

```java
// 重定向
HttpServletResponse.sendRedirect(userInput)
new RedirectView(userInput)
return "redirect:" + userInput

// Forward
request.getRequestDispatcher(userInput).forward(request, response)
return "forward:" + userInput

// Spring MVC
@RequestMapping("/go")
public String go(@RequestParam String url) {
    return "redirect:" + url;  // 危险
}
```

## 绕过技术

| 绕过方式 | 示例 |
|----------|------|
| 协议绕过 | `javascript:alert(1)` |
| 域名绕过 | `https://evil.com?ref=trusted.com` |
| 编码绕过 | `https://%65%76%69%6c.com` |
| 子域名绕过 | `https://trusted.evil.com` |
| URL解析差异 | `https://trusted.com@evil.com` |
| 反斜杠 | `https://trusted.com\@evil.com` |

## 安全实现

```java
// 白名单域名校验
private static final Set<String> ALLOWED_DOMAINS = Set.of("example.com", "app.example.com");

public void redirect(String url) {
    URI uri = URI.create(url);
    if (!ALLOWED_DOMAINS.contains(uri.getHost())) {
        throw new IllegalArgumentException("Invalid redirect URL");
    }
    response.sendRedirect(url);
}
```

## 审计流程

```
1. 定位重定向/Forward Sink点
2. 反向追踪URL参数来源
3. 检查是否存在域名白名单
4. 检查是否阻止危险协议
5. 使用LSP确认URL可控性
6. 生成漏洞报告或标记为安全
```

## 输出格式

```json
{
  "branch": "redirect",
  "findings": [
    {
      "type": "开放重定向",
      "severity": "MEDIUM",
      "sink": "AuthController.java:78",
      "source": "AuthController.java:72 @RequestParam returnUrl",
      "evidence": "return \"redirect:\" + returnUrl",
      "sanitization": "无域名白名单校验",
      "poc": "GET /login?returnUrl=https://evil.com/phishing"
    }
  ]
}
```
