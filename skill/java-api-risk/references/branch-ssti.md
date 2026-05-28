# SSTI模板注入审计分支

## 触发条件

- 标签: `TEMPLATE_RENDER`, `TH_UTEXT`, `FREEMARKER_NEW`, `VELOCITY_REFLECT`
- 优先级: 1（高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| SSTI1 | 模板内容是否来自用户可控输入？ |
| SSTI2 | 是否使用沙箱限制模板执行能力？ |
| SSTI3 | Freemarker是否禁用`?new()`内置函数？ |
| SSTI4 | Thymeleaf是否使用`th:text`而非`th:utext`？ |
| SSTI5 | Velocity是否禁用反射和类加载？ |
| SSTI6 | 模板名称/路径是否可控（视图名注入）？ |
| SSTI7 | 是否阻止模板中调用Java类（`Class.forName`, `Runtime`）？ |

## 危险Sink清单

```java
// Freemarker
Configuration.getTemplate(userInput).process(data, writer)
new Template("name", new StringReader(userInput), cfg)
// 危险内置: ?new(), ObjectConstructor, Execute, Jython

// Thymeleaf
templateEngine.process(userInput, context)
// 视图名注入: return "template/" + userInput
// th:utext 不转义输出

// Velocity
VelocityEngine.evaluate(context, writer, "tag", userInput)
// 反射利用: #set($rt = $class.forName("java.lang.Runtime"))

// Pebble
PebbleEngine.getTemplate(userInput)

// XSLT
TransformerFactory.newTransformer(new StreamSource(userInput))
```

## 各引擎沙箱逃逸

| 引擎 | 逃逸方式 |
|------|----------|
| Freemarker | `?new("freemarker.template.utility.Execute")` |
| Freemarker | `?new("freemarker.template.utility.ObjectConstructor")` |
| Thymeleaf | `T(java.lang.Runtime).getRuntime().exec()` |
| Velocity | `$class.forName("java.lang.Runtime").getMethod("exec","".class)` |
| XSLT | `<xsl:script>` 或 `Runtime.exec()` via extension |

## 审计流程

```
1. 定位模板渲染Sink点
2. 识别使用的模板引擎
3. 区分：模板内容注入 vs 模板名称注入
4. 反向追踪模板来源
5. 检查是否存在沙箱/安全配置
6. 验证沙箱是否可逃逸
7. 使用LSP确认参数可控性
8. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- 模板来自数据库/配置中心 → 追踪模板写入来源
- 模板名称来自路由参数 → 确认视图解析逻辑

## 输出格式

```json
{
  "branch": "ssti",
  "findings": [
    {
      "type": "SSTI (Freemarker)",
      "severity": "CRITICAL",
      "sink": "TemplateService.java:34",
      "source": "TemplateController.java:18 @RequestBody",
      "evidence": "new Template(\"t\", new StringReader(userTemplate), cfg).process(data, out)",
      "sanitization": "无沙箱，?new()未禁用",
      "poc": "<#assign ex=\"freemarker.template.utility.Execute\"?new()>${ex(\"id\")}"
    }
  ]
}
```
