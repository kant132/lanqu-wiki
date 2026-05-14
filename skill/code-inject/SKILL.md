---
name: code-inject
description: Load when user mentions Java code injection, SpEL injection, OGNL injection, EL injection, Freemarker SSTI, Velocity SSTI, Thymeleaf SSTI, Groovy injection, Beanshell injection, MVEL injection, Struts2 vulnerability, expression injection, template injection, RCE audit, JMX vulnerability, BPMN workflow injection, or Java deserialization exploit chain. NOT for non-Java languages.
---

# Java 代码注入审计

## 核心规则

1. **不要将表达式注入和模板注入混为一谈**——表达式引擎在运行时求值单表达式，模板引擎渲染含模板语法的文档，审计方法完全不同
2. **不要只检查直接用户输入**——SpEL/OGNL常通过间接路径注入(如HTTP Header、Cookie、URL Path变量、配置文件热加载)
3. **没有确认沙箱实际生效之前，不要判定"有沙箱保护所以安全"**——Freemarker/Nashorn的沙箱均存在已知逃逸方式
4. **不要忽略框架隐式调用**——Spring的@Value("#{...}")、Struts2的OGNL值栈、Thymeleaf的视图名解析都会隐式触发表达式求值
5. **Struts2项目不要只看OGNL**——Struts2同时存在BME注入路径(AP3502.905)
6. **不要将Groovy Eval.me和GroovyShell.evaluate视为同一漏洞模式**——前者只能算单表达式，后者可执行任意脚本块

## Sink点识别

### 什么是Sink点
Sink点 = 代码中调用表达式/模板引擎API的**危险函数调用**，其参数如果可控则会触发代码执行。

### Sink点识别步骤

1. **grep搜索引擎特定API** → 定位可能的Sink点
2. **LSP回溯参数来源** → 从Sink点向上回溯，确认参数是否来自外部输入
3. **检查框架隐式调用** → 有些注入点不通过显式API调用触发

## 审计检查点

### 检查点1：定位Sink点 (使用grep + LSP)

**Grep搜索关键词** (按引擎分类):

| 引擎 | Sink点API (grep模式) |
|------|---------------------|
| SpEL | `SpelExpressionParser`, `parseExpression`, `getValue()` |
| OGNL | `Ognl.getValue`, `ValueStack.findValue` |
| Groovy | `GroovyShell.evaluate`, `GroovyShell.parse`, `Eval.me` |
| Freemarker | `Configuration.getTemplate`, `Template.process` |
| Velocity | `Velocity.evaluate`, `mergeTemplate` |
| Thymeleaf | `SpringTemplateEngine.process`, `ViewResolver` |
| MVEL | `MVEL.eval`, `MVEL.compileExpression`, `executeExpression` |
| Jexl | `JexlEngine.createExpression`, `Expression.evaluate` |
| Beanshell | `bsh.Interpreter.eval`, `Interpreter.source` |
| Nashorn | `ScriptEngine.eval`, `getEngineByName("nashorn")` |
| XSLT | `TransformerFactory.newTransformer`, `Templates.newInstance` |

**通过grep找到候选Sink点后，使用LSP执行以下操作**：

1. 对每个Sink点的参数进行**Find References**（查找引用）
2. 对参数进行**Go to Definition**（转到定义）追溯来源
3. 确认参数是否来自外部输入(HttpServletRequest/Header/Cookie/配置文件/数据库)

### 检查点2：参数来源可控性分析

**LSP回溯路径示例**：

```
Sink点: parser.parseExpression(userInput)
  ↓ LSP: Find References on 'userInput'
  ↓ 发现: userInput = request.getParameter("expr")
  ↓ 结论: 参数来自HTTP请求，属于外部输入 → 可控
```

**验证条件**：注入点参数的调用链中至少有一处来自外部输入
- 通过 → 进入检查点3
- 失败 → 结束(不可控=无风险)

### 检查点3：防护绕过评估

**验证条件**：
1. 确认是否存在防护(沙箱/白名单/SecurityManager)
2. 使用LSP检查防护代码是否存在且生效
3. 验证该防护是否可绕过

**防护可绕过或无防护** → 报告漏洞
**防护无法绕过** → 记录为已缓解，标注防护方式

## 分类路由

| 当你看到/用户提到 | 读取Reference | Sink点Grep模式 |
|-------------------|--------------|----------------|
| SpEL, Spring表达式, @Value("#{"), ExpressionParser | `references/expression-engine-inject.md` §SpEL | `SpelExpressionParser`, `parseExpression` |
| OGNL, Struts2值栈, ValueStack.findValue | `references/expression-engine-inject.md` §OGNL | `Ognl.getValue`, `ValueStack.findValue` |
| EL, ${}, ExpressionFactory | `references/expression-engine-inject.md` §EL | `ExpressionFactory.createValueExpression` |
| Groovy, Eval.me, GroovyShell | `references/expression-engine-inject.md` §Groovy + `references/jvm-features-inject.md` §GroovyEval | `GroovyShell.evaluate`, `Eval.me` |
| Beanshell | `references/expression-engine-inject.md` §Beanshell | `bsh.Interpreter.eval` |
| MVEL | `references/expression-engine-inject.md` §MVEL + `references/template-engine-inject.md` §MVEL模板 | `MVEL.eval`, `MVEL.compileExpression` |
| Freemarker, FTL, <#if | `references/template-engine-inject.md` §Freemarker | `Configuration.getTemplate`, `Template.process` |
| Velocity, VTL | `references/template-engine-inject.md` §Velocity | `Velocity.evaluate`, `mergeTemplate` |
| Thymeleaf | `references/template-engine-inject.md` §Thymeleaf | `SpringTemplateEngine.process` |
| Pebble, Jinjava | `references/template-engine-inject.md` §其他引擎 | `PebbleEngine.getTemplate`, `Jinjava.render` |
| XSLT | `references/template-engine-inject.md` §XSLT | `TransformerFactory.newTransformer` |
| Drools, KieSession | `references/expression-engine-inject.md` §规则引擎 | `KieSession.fireAllRules` |
| Struts2, Action | `references/expression-engine-inject.md` §Struts2/BME | `ParametersInterceptor`, `ActionContext` |
| JMX, MBean | `references/jvm-features-inject.md` §JMX | `MBeanServer.registerMBean` |
| Gradle, build.gradle | `references/jvm-features-inject.md` §构建注入 | `apply from`, `doLast` |
| Activiti, Camunda, BPMN | `references/workflow-engine-inject.md` | `ProcessEngine.getRuntimeService` |
| Nashorn, ScriptEngine | `references/expression-engine-inject.md` §Nashorn | `ScriptEngine.eval` |
| 一般性Java代码注入 | 先读 `references/expression-engine-inject.md` | 综合grep |

## 审计常见错误

- ❌ **搜索`eval`关键词** → Java没有原生eval，要搜索的是`ExpressionParser.evaluate`/`GroovyShell.evaluate`等引擎特定API
- ❌ **只看Controller层直接参数** → Struts2 OGNL注入点在Action的setter/getter链和拦截器参数中
- ❌ **发现Freemarker用`autoescape`就认为安全** → autoescape只防XSS，不防SSTI的`<#if>`/`${}`指令注入
- ❌ **Spring项目中只检查SpEL** → Spring同时集成Thymeleaf(视图操纵)和Freemarker(SSTI)，需全部检查
- ❌ **看到`ScriptEngine`不跟进** → Nashorn引擎的ScriptContext可能被外部操控
- ❌ **grep找到Sink点就报告漏洞** → 必须用LSP回溯确认参数可控，Sink点存在≠漏洞

## 信息不足时必须询问

当用户没有提供以下信息时，不得自行假设，必须先询问：
1. 目标Java项目使用的主要框架(Spring/Struts2/其他)
2. 是否使用了表达式引擎/模板引擎/规则引擎(具体哪个)
3. 代码是反编译的还是源码(反编译代码的grep模式可能不同)
4. 审计目标是发现漏洞还是验证已知漏洞