# Code-Injection Skill 创建计划 V2 (Java Only)

> 基于 V1 修订，对照《Agent Skill 写作完全指南》逐项检查后优化

## 〇、V1→V2 变更摘要

| #   | 检查项           | V1问题             | V2修改                                 |
| --- | ------------- | ---------------- | ------------------------------------ |
| 1   | Description格式 | 功能描述式，超200字符     | 改为`Load when`开头，≤200字符               |
| 2   | 否定式规则         | 无                | 增加6条否定式核心规则                          |
| 3   | 只写模型不知道的      | 包含通用审计流程(模型自己就会) | 删除通用流程，只保留易犯错点                       |
| 4   | 检查点           | 无                | 增加3步审计检查点                            |
| 5   | 信息不足时"问"      | 无                | 增加"必须询问"指令                           |
| 6   | 原子性/内容量       | 40+模式可能超阈值       | SKILL.md仅保留路由+核心规则，详细模式全部下沉reference |
| 7   | SKILL.md定位    | 像百科导航页           | 重构为规则驱动型                             |
| 8   | reference加载条件 | 只写"见xxx"         | 增加明确读取触发条件                           |
| 9   | 常见错误          | 无                | 增加"审计常见错误"板块                         |

## 一、Wiki 内容结构概览

源地址: https://wiki.huawei.com/domains/530/wiki/4790/WIKI2021082700387

**范围**: 仅 Java/JVM 代码安全审计

Java 相关子模式:
```
35 代码注入
├── AP3502 表达式引擎注入 (22个) — SpEL/OGNL/EL/Groovy/MVEL/Beanshell/Fel/Jexl/Jsel/Aviator/QLExpress/Nashorn/JRuby/Jython/Drools/EasyRules/Struts2/BME/JasperReport/MEL
├── AP3503 Java模板引擎注入 (13个) — Freemarker系/Velocity/Thymeleaf/Pebble/Jinjava/GroupTemplate/TemplateEngine/MVEL模板/XSLT
├── AP3504 工作流引擎注入 (1个) — BPMN(Activiti/Camunda/Flowable)
└── JVM特性注入 (6个) — Groovy Eval/JMX-RMI/javac注解处理器/Swing HTML/Gradle构建/代码构建过程可控
```

## 二、Skill 设计方案

### 2.1 基本信息

- **name**: `code-inject`
- **description**: `Load when user mentions Java code injection, SpEL injection, OGNL injection, EL injection, Freemarker SSTI, Velocity SSTI, Thymeleaf SSTI, Groovy injection, Beanshell injection, MVEL injection, Struts2 vulnerability, expression injection, template injection, RCE audit, JMX vulnerability, BPMN workflow injection, or Java deserialization exploit chain. NOT for non-Java languages.`

### 2.2 文件结构

```
code-inject/
├── SKILL.md                              # 主文件 (~200行)
│   ├── frontmatter (name, description)
│   ├── 核心规则 (否定式, ≤10条)
│   ├── 审计检查点 (3步)
│   ├── 分类路由 + 读取触发条件
│   ├── 审计常见错误
│   └── 信息不足时询问清单
│
├── references/
│   ├── expression-engine-inject.md       # AP3502 (~350行)
│   ├── template-engine-inject.md         # AP3503 (~250行)
│   ├── workflow-engine-inject.md         # AP3504 (~80行)
│   └── jvm-features-inject.md            # AP3501+AP3505 (~180行)
```

### 2.3 SKILL.md 核心内容

```markdown
---
name: code-inject
description: Load when user mentions Java code injection, SpEL injection, OGNL injection, EL injection, Freemarker SSTI, Velocity SSTI, Thymeleaf SSTI, Groovy injection, Beanshell injection, MVEL injection, Struts2 vulnerability, expression injection, template injection, RCE audit, JMX vulnerability, BPMN workflow injection, or Java deserialization exploit chain. NOT for non-Java languages.
---

# Java 代码注入审计

## 核心规则

1. 不要将表达式注入和模板注入混为一谈——表达式引擎在运行时求值单表达式，模板引擎渲染含模板语法的文档，审计方法完全不同
2. 不要只检查直接用户输入——SpEL/OGNL常通过间接路径注入(如HTTP Header、Cookie、URL Path变量、配置文件热加载)
3. 没有确认沙箱实际生效之前，不要判定"有沙箱保护所以安全"——Freemarker/Nashorn的沙箱均存在已知逃逸方式
4. 不要忽略框架隐式调用——Spring的@Value("#{...}")、Struts2的OGNL值栈、Thymeleaf的视图名解析都会隐式触发表达式求值
5. Struts2项目不要只看OGNL——Struts2同时存在BME注入路径(AP3502.905)
6. 不要将Groovy Eval.me和GroovyShell.evaluate视为同一漏洞模式——前者只能算单表达式，后者可执行任意脚本块

## 审计检查点

### 检查点1：定位注入点
验证条件：代码中存在表达式/模板引擎的入口API调用
通过 → 进入检查点2
失败 → 检查是否有框架隐式调用(@Value、@PreAuthorize、Struts2 Action等)，仍无则结束

### 检查点2：参数来源可控性
验证条件：注入点参数的调用链中至少有一处来自外部输入(HttpServletRequest/Header/Cookie/配置文件/数据库用户字段)
通过 → 进入检查点3
失败 → 结束(不可控=无风险)

### 检查点3：防护绕过评估
验证条件：确认是否存在防护(沙箱/白名单/SecurityManager)，并验证该防护是否可绕过
防护可绕过或无防护 → 报告漏洞
防护无法绕过 → 记录为已缓解，标注防护方式

## 分类路由

| 当你看到/用户提到 | 读取 | 子模式数 |
|-------------------|------|----------|
| SpEL, Spring表达式, @Value("#{"), ExpressionParser | `references/expression-engine-inject.md` §SpEL | - |
| OGNL, Struts2值栈, ValueStack.findValue, ognl.OgnlRuntime | `references/expression-engine-inject.md` §OGNL | - |
| EL, ${}, ExpressionFactory, ValueExpression | `references/expression-engine-inject.md` §EL | - |
| Groovy, Eval.me, GroovyShell, GroovyClassLoader | `references/expression-engine-inject.md` §Groovy + `references/jvm-features-inject.md` §GroovyEval | - |
| Beanshell, Interpreter, bsh.Interpreter | `references/expression-engine-inject.md` §Beanshell | - |
| MVEL, MVEL.eval, MVEL.compileExpression | `references/expression-engine-inject.md` §MVEL + `references/template-engine-inject.md` §MVEL模板 | - |
| Freemarker, FTL, <#if, ${}, Configuration.getTemplate | `references/template-engine-inject.md` §Freemarker | - |
| Velocity, VTL, #if, #set, Velocity.evaluate | `references/template-engine-inject.md` §Velocity | - |
| Thymeleaf, th:text, ViewResolver, SpringTemplateEngine | `references/template-engine-inject.md` §Thymeleaf | - |
| Pebble, Jinjava, GroupTemplate, TemplateEngine | `references/template-engine-inject.md` §其他引擎 | - |
| XSLT, TransformerFactory, Templates | `references/template-engine-inject.md` §XSLT | - |
| Drools, RuleFlow, KieSession, Easy Rules | `references/expression-engine-inject.md` §规则引擎 | - |
| Struts2, Action, BME | `references/expression-engine-inject.md` §Struts2/BME | - |
| JMX, MBeanServer, RMI, JMXConnector | `references/jvm-features-inject.md` §JMX | - |
| Gradle, build.gradle, javac, Processor | `references/jvm-features-inject.md` §构建注入 | - |
| Activiti, Camunda, Flowable, BPMN, ProcessEngine | `references/workflow-engine-inject.md` | - |
| Nashorn, ScriptEngine, JavaScript引擎 | `references/expression-engine-inject.md` §Nashorn | - |
| JasperReport, MEL, DataWeave | `references/expression-engine-inject.md` §报表组件 | - |
| 一般性"Java代码注入"，无法定位分类 | 先读取 `references/expression-engine-inject.md` (占60%+案例)，再根据线索补充 | - |

## 审计常见错误

- ❌ 搜索`eval`关键词 → Java没有原生eval，要搜索的是`ExpressionParser.evaluate`/`GroovyShell.evaluate`等引擎特定API
- ❌ 只看Controller层直接参数 → Struts2 OGNL注入点在Action的setter/getter链和拦截器参数中
- ❌ 发现Freemarker用`autoescape`就认为安全 → autoescape只防XSS，不防SSTI的`<#if>`/`${}`指令注入
- ❌ Spring项目中只检查SpEL → Spring同时集成Thymeleaf(视图操纵)和Freemarker(SSTI)，需全部检查
- ❌ 看到`new ScriptEngineManager().getEngineByName("nashorn")`不跟进 → Nashorn引擎的ScriptContext可能被外部操控

## 信息不足时必须询问

当用户没有提供以下信息时，不得自行假设，必须先询问：
1. 目标Java项目使用的主要框架(Spring/Struts2/其他)
2. 是否使用了表达式引擎/模板引擎/规则引擎(具体哪个)
3. 代码是反编译的还是源码(反编译代码的grep模式可能不同)
4. 审计目标是发现漏洞还是验证已知漏洞
```

### 2.4 Reference 文件内容规划

每个 reference 文件统一结构:
```markdown
# [分类名称]

## 目录
| 子模式 | 关键API/组件 | 严重度 |
|--------|-------------|--------|

## [子模式1名称] (APxxxx.xxx)
### 场景
### 漏洞发现 — grep关键词 + 回溯路径
### 漏洞利用 — POC(仅关键片段)
### 案例(如有)
### 防护建议

## [子模式2名称] (APxxxx.xxx)
...
```

### 2.5 各 Reference 文件内容清单

#### expression-engine-inject.md (~350行, 22个子模式)

| §分组 | 子模式 | 关键API |
|-------|--------|---------|
| §SpEL | AP3502.901 SpEL注入 | ExpressionParser, SpelExpressionParser, parseExpression, StandardEvaluationContext |
| §OGNL | AP3502.002 OGNL注入 | Ognl.getValue, Ognl.parseExpression, ValueStack.findValue |
| §OGNL | AP3502.906 Struts2 OGNL | ActionContext, ParametersInterceptor, ServletActionContext |
| §EL | AP3502.902 EL注入 | ValueExpression.getValue, ExpressionFactory.createValueExpression, ELResolver |
| §Groovy | AP3502.903 Groovy注入 | GroovyShell.evaluate/parse, GroovyClassLoader.parseClass |
| §Beanshell | AP3502.907 Beanshell注入 | Interpreter.eval, Interpreter.source |
| §MVEL | AP3502.910 MVEL注入 | MVEL.eval, MVEL.compileExpression, MVEL.executeExpression |
| §Jexl | AP3502.908 Jexl注入 | JexlEngine.createExpression, Expression.evaluate |
| §Fel | AP3502.909 Fel注入 | Fel.eval, FelEngine.eval |
| §Jsel | AP3502.911 Jsel注入 | JselEvaluator.evaluate, ExpressionEngine |
| §Aviator | AP3502.007 Aviator注入 | AviatorEvaluator.execute/compile |
| §QLExpress | AP3502.005 QLExpress注入 | QLExpressRunTime.evaluate, ExpressRunner.execute |
| §Nashorn | AP3502.001 JS引擎注入 | ScriptEngine.eval, ScriptEngineManager.getEngineByName |
| §Nashorn | AP3502.003 Nashorn沙箱逃逸 | delight-nashorn-sandbox, NashornSandbox.eval |
| §JRuby | AP3502.004 JRuby注入 | ScriptingContainer.parse/run/eval |
| §Jython | AP3502.006 Jython注入 | PythonInterpreter.exec/eval |
| §Drools | AP3502.912 Drools注入 | KieSession.fireAllRules, RuleFlowProcess |
| §EasyRules | AP3502.015 Easy Rules注入 | RulesEngine.fire, Rule.when/then |
| §Struts2 | AP3502.904 Struts2代码注入 | Action chain, redirect参数 |
| §BME | AP3502.905 BME注入 | BME框架特定API |
| §JasperReport | AP3502.913 Jasper注入 | JasperReport表达式, JREvaluator |
| §MEL | AP3502.914 MEL/DataWeave注入 | Mule Expression Language, DataWeave |

#### template-engine-inject.md (~250行, 13个子模式)

| §分组 | 子模式 | 关键API |
|-------|--------|---------|
| §Freemarker | AP3503.008 Freemarker模板注入 | Configuration.getTemplate, Template.process |
| §Freemarker | AP3503.907 ${}/#{}渲染命令执行 | Environment.process, ObjectWrapper |
| §Freemarker | AP3503.908 Template/TemplateModel | TemplateModel, SimpleScalar |
| §Freemarker | AP3503.909 NodeModel XXE | NodeModel.parse, XMLEnvironment |
| §Freemarker | AP3503.910 Matches ReDoS | ?matches内建函数 |
| §Velocity | AP3503.004 Velocity注入 | Velocity.evaluate, Velocity.mergeTemplate |
| §Thymeleaf | AP3503.914 视图操纵 | TemplateEngine.process, ViewResolver |
| §Pebble | AP3503.915 Pebble注入 | PebbleEngine.getTemplate, PebbleTemplate.evaluate |
| §Jinjava | AP3503.916 Jinjava注入 | Jinjava.render |
| §GroupTemplate | AP3503.917 GroupTemplate注入 | GroupTemplate.getTemplate, Template.render |
| §TemplateEngine | AP3503.913 TemplateEngine注入 | TemplateEngine.process |
| §MVEL模板 | AP3503.009 MVEL模板注入 | MVEL模板语法 |
| §XSLT | AP3503.006 XSLT注入 | TransformerFactory, Templates |

#### workflow-engine-inject.md (~80行, 1个子模式)

| 子模式 | 关键API |
|--------|---------|
| AP3504.001 BPMN工作流注入 | ProcessEngine, RuntimeService.startProcessInstanceByKey, conditionExpression, Execution |

#### jvm-features-inject.md (~180行, 6个子模式)

| 子模式 | 关键API |
|--------|---------|
| Groovy Eval.me/xyz/x/y | Eval.me, Eval.xyz, Eval.x, Eval.y |
| GroovyShell.parse/evaluate | GroovyShell, GroovyClassLoader.parseClass, GroovyScriptEngine.run |
| JMX RMI注册漏洞 | MBeanServer, JMXConnector, JMXServiceURL, mlet |
| javac注解处理器注入 | Processor.process, Filer, javac编译 |
| Swing HTML渲染注入 | JEditorPane.setContentType("text/html"), HTMLEditorKit |
| Gradle/构建过程注入 | build.gradle, apply from, Maven plugin exec |

## 三、加载策略

| 层级 | 内容 | 加载时机 | 预估行数 |
|------|------|----------|----------|
| L1: Metadata | name + description | 始终 | ~5行 |
| L2: SKILL.md | 核心规则+检查点+路由表+常见错误+询问清单 | skill触发时 | ~200行 |
| L3: references/ | 具体子模式详情 | 用户问及特定引擎/组件时按需读取 | 80-350行/文件 |

## 四、创建步骤

### Phase 1: 数据采集
1. 浏览器逐一打开 ~42 个Java相关子页面
2. 提取: 场景描述、漏洞发现(grep关键词+回溯路径)、POC关键片段、案例摘要、防护建议
3. 跳过非Java页面

### Phase 2: 内容整理
1. 去除无关信息(修订记录、会签、头像等)
2. wiki→Markdown转换
3. 精简: 每个子模式控制在15-25行(场景+发现+POC+防护)
4. 全文POC仅保留关键片段，不粘贴完整攻击脚本

### Phase 3: Skill 文件创建
1. 创建 SKILL.md
2. 创建 references/ 及4个文件
3. 验证SKILL.md < 500行，description ≤ 200字符

### Phase 4: 验证
1. frontmatter格式正确(name小写连字符、description以Load when开头)
2. 所有references路径引用正确
3. 否定式规则可执行(非模糊描述)
4. 检查点有通过/失败条件

## 五、删除清单 (非Java内容)

| 原始分类 | 删除项 | 原因 |
|----------|--------|------|
| AP3501 | Lua/Python/PHP/NodeJS/Ruby/Perl/Shell 内置函数 | 非Java |
| AP3503 | Flask/Jinja2/Tornado/Mako/Django | Python模板引擎 |
| AP3503 | NodeJS-Jade/Pug | NodeJS模板引擎 |
| AP3505 | C#反射注解值注入 | .NET |
| AP3505 | Terraform配置注入 | IaC，非Java |
| AP3505 | Ansible可控剧本注入 | IaC，非Java |
| AP3505 | 反向代理配置可控命令注入 | 非Java |

## 六、预计产出

| 文件 | 预估行数 |
|------|----------|
| SKILL.md | ~200行 |
| references/expression-engine-inject.md | ~350行 |
| references/template-engine-inject.md | ~250行 |
| references/workflow-engine-inject.md | ~80行 |
| references/jvm-features-inject.md | ~180行 |
| **总计** | **~1060行** |

---

**状态**: 待审批
**版本**: V2
**更新时间**: 2026-05-14
**V1→V2关键变更**: description改为Load when格式、增加否定式核心规则、增加审计检查点、增加常见错误板块、增加信息不足询问指令、删除通用流程(模型自己就会)、路由表增加具体触发关键词和读取条件
**等待用户确认后方可执行创建**