# Java Sink 点

Java 代码中调用外部脚本解释器或执行命令的 sink 点。

## Runtime 类

### Runtime.exec()
```
grep 模式:
  Runtime\.getRuntime\(\)\.exec\s*\(
  \.exec\s*\(
```
**风险：** 当传入单个 String 参数时，由 `StringTokenizer` 分词（不经过 shell）。但如果字符串包含 `sh -c` 或 `bash -c`，会重新启用 shell 解释。数组形式 `exec(String[])` 直接传递参数。

## ProcessBuilder

### ProcessBuilder 构造 + start()
```
grep 模式:
  new\s+ProcessBuilder\s*\(
  ProcessBuilder\s*\(
  \.start\s*\(\s*\)
```
**风险：** 参数以列表形式传递（不经过 shell 解释）。当使用 `sh -c` 或 `bash -c` 作为命令，或参数由用户输入构建时产生危险。

## 内联解释器调用模式

以下模式在 Java 代码中标记为**高风险**：

| 模式 | 示例 |
|------|------|
| `exec("sh -c ...")` | `Runtime.getRuntime().exec("sh -c 'process " + input + "'")` |
| `exec("bash -c ...")` | `Runtime.getRuntime().exec("bash -c 'run " + arg + "'")` |
| `ProcessBuilder("sh", "-c", ...)` | `new ProcessBuilder("sh", "-c", "run " + userInput)` |
| `ProcessBuilder("bash", "-c", ...)` | `new ProcessBuilder("bash", "-c", cmd)` |
| `ProcessBuilder("perl", "-e", ...)` | `new ProcessBuilder("perl", "-e", code)` |
| `ProcessBuilder("python", "-c", ...)` | `new ProcessBuilder("python", "-c", cmd)` |
| `ProcessBuilder("lua", "-e", ...)` | `new ProcessBuilder("lua", "-e", script)` |

## Sink 前的字符串构造

```
grep 模式:
  String\.format\s*\(
  \+.*\+                  （字符串拼接）
  StringBuilder.*append
  StringBuffer.*append
  MessageFormat\.format
  String\.join
```

当这些构造方式生成的字符串被传入 `Runtime.exec(String)` 或在 `ProcessBuilder` 中与 `sh -c` 一起使用时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: exec\s*\([^)]*\.(sh|pl|py|lua)
grep 模式: ProcessBuilder\s*\([^)]*\.(sh|pl|py|lua)
```

## ScriptEngine (javax.script)

```
grep 模式:
  ScriptEngineManager
  ScriptEngine.*eval\s*\(
  javax\.script
```
**风险：** `ScriptEngine.eval()` 在 JVM 内执行脚本。如果脚本内容或绑定包含用户输入，可能导致代码注入。
