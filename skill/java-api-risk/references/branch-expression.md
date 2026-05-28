# 表达式注入审计分支

## 触发条件

- 标签: `EXPRESSION_PARSE`, `OGNL`, `EL_INJECT`, `MVEL_EVAL`, `BEANSHELL`, `GROOVY_EVAL`, `NASHORN`
- 优先级: 1（高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| EX1 | 表达式字符串是否来自用户可控输入？ |
| EX2 | SpEL是否使用`SimpleEvaluationContext`而非`StandardEvaluationContext`？ |
| EX3 | OGNL是否配置了`SecurityMemberAccess`限制类访问？ |
| EX4 | EL是否禁用了反射和类加载？ |
| EX5 | MVEL是否禁用了`import`和类实例化？ |
| EX6 | Groovy是否使用`CompilerConfiguration`白名单？ |
| EX7 | Nashorn是否使用`--no-java`选项禁用Java互操作？ |
| EX8 | Beanshell是否限制了可调用的类？ |
| EX9 | 是否存在框架隐式调用（`@Value("#{...}")`、`@PreAuthorize`）？ |

## 危险Sink清单

```java
// SpEL
SpelExpressionParser.parseExpression(userInput)
StandardEvaluationContext  // 无限制上下文
// 安全替代: SimpleEvaluationContext

// OGNL (Struts2)
OgnlUtil.getValue(userInput, context, root)
ValueStack.findValue(userInput)
// 隐式: Struts2标签属性、ParametersInterceptor

// EL (JSP/JSF)
ExpressionFactory.createValueExpression(context, userInput, type)
ValueExpression.getValue(context)

// MVEL
MVEL.eval(userInput, vars)
MVEL.compileExpression(userInput)

// Beanshell
bsh.Interpreter.eval(userInput)
new Interpreter().eval(userInput)

// Groovy
Eval.me(userInput)
GroovyShell.evaluate(userInput)  // 可执行任意脚本块
GroovyClassLoader.parseClass(userInput)

// Nashorn/ScriptEngine
ScriptEngine.eval(userInput)
NashornScriptEngine.eval(userInput)
// 注意: ScriptContext可能被外部操控
```

## 各引擎RCE Payload

| 引擎 | Payload |
|------|---------|
| SpEL | `T(java.lang.Runtime).getRuntime().exec('id')` |
| OGNL | `(#rt=@java.lang.Runtime@getRuntime()).(#rt.exec('id'))` |
| EL | `${Runtime.getRuntime().exec('id')}` |
| MVEL | `Runtime.getRuntime().exec('id')` |
| Beanshell | `Runtime.getRuntime().exec("id")` |
| Groovy | `"id".execute().text` |
| Nashorn | `java.lang.Runtime.getRuntime().exec('id')` |

## 审计流程

```
1. 定位表达式求值Sink点
2. 识别使用的表达式引擎
3. 区分：表达式注入 vs 模板注入（不要混淆）
4. 反向追踪表达式字符串来源
5. 检查EvaluationContext安全配置
6. 检查是否存在沙箱/类访问限制
7. 验证沙箱是否可逃逸
8. 检查框架隐式调用路径
9. 使用LSP确认参数可控性
10. 生成漏洞报告或标记为安全
```

## 框架隐式调用检查

| 框架 | 隐式调用路径 |
|------|--------------|
| Spring | `@Value("#{userInput}")` |
| Spring | `@PreAuthorize("hasRole(userInput)")` |
| Spring | `@Cacheable(key="userInput")` |
| Struts2 | Action属性名自动OGNL求值 |
| Struts2 | `ParametersInterceptor` 参数名注入 |
| Thymeleaf | 视图名中的SpEL表达式 |

## 回溯请求触发条件

- 表达式来自配置文件热加载 → 追踪配置写入权限
- 表达式来自数据库规则引擎 → 检查规则编辑权限
- 框架隐式调用 → 追踪注解参数来源

## 输出格式

```json
{
  "branch": "expression",
  "findings": [
    {
      "type": "SpEL注入",
      "severity": "CRITICAL",
      "sink": "RuleService.java:67",
      "source": "RuleController.java:24 @RequestParam",
      "evidence": "parser.parseExpression(userExpr).getValue()",
      "context_type": "StandardEvaluationContext (无限制)",
      "sanitization": "无SimpleEvaluationContext，无类白名单",
      "poc": "GET /api/rule?expr=T(java.lang.Runtime).getRuntime().exec('id')"
    }
  ]
}
```
