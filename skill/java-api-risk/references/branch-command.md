# 命令注入审计分支

## 触发条件

- 标签: `COMMAND_EXEC`, `PROCESS_BUILDER`
- 优先级: 1（高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| CMD1 | 命令参数是否来自用户可控输入？ |
| CMD2 | 是否使用`ProcessBuilder`数组形式而非字符串拼接？ |
| CMD3 | 是否避免使用`/bin/sh -c`或`cmd /c`？ |
| CMD4 | 是否对参数进行白名单验证或转义？ |
| CMD5 | 是否限制可执行命令范围？ |

## 危险Sink清单

```java
// Runtime.exec
Runtime.getRuntime().exec(command)
Runtime.getRuntime().exec(new String[]{"/bin/sh", "-c", command})  // 若command拼接

// ProcessBuilder
new ProcessBuilder(command).start()
new ProcessBuilder("/bin/sh", "-c", userInput).start()

// 间接调用
ScriptEngine.eval("java.lang.Runtime.getRuntime().exec('" + userInput + "')")
```

## 安全替代方案

```java
// 不安全: 字符串拼接
Runtime.getRuntime().exec("ping " + userInput);

// 安全: 数组形式 + 白名单
List<String> allowedHosts = Arrays.asList("google.com", "github.com");
if (!allowedHosts.contains(userInput)) {
    throw new IllegalArgumentException("Invalid host");
}
new ProcessBuilder("ping", "-c", "4", userInput).start();
```

## 审计流程

```
1. 定位命令执行Sink点
2. 检查命令构建方式（字符串 vs 数组）
3. 反向追踪命令参数来源
4. 检查是否存在白名单/转义
5. 检查是否使用shell解释器
6. 使用LSP确认参数可控性
7. 生成漏洞报告或标记为安全
```

## 输出格式

```json
{
  "branch": "command",
  "findings": [
    {
      "type": "命令注入",
      "severity": "CRITICAL",
      "sink": "NetworkService.java:56",
      "source": "DiagController.java:22 @RequestParam",
      "evidence": "Runtime.getRuntime().exec(\"ping \" + host)",
      "sanitization": "无白名单，无转义",
      "poc": "GET /api/diag/ping?host=;cat /etc/passwd"
    }
  ]
}
```
