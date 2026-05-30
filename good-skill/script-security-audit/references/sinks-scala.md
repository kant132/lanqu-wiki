# Scala Sink 点

Scala 代码中调用外部脚本解释器或执行命令的 sink 点。

## Java 继承类（JVM 上运行）

### Runtime.exec()
```
grep 模式:
  Runtime\.getRuntime\(\)\.exec\s*\(
  \.exec\s*\(
```
**风险：** 与 Java 相同。参数传递给 `StringTokenizer` 分词（不经过 shell），但包含 `sh -c` 或 `bash -c` 时重新启用 shell 解释。

### ProcessBuilder
```
grep 模式:
  new\s+ProcessBuilder\s*\(
  ProcessBuilder\s*\(
  ProcessBuilder\(".*"\)\.start
```
**风险：** 与 Java 相同。
- Scala 3.x: `ProcessBuilder("touch","/tmp/1").start`
- Scala 2.x: `ProcessBuilder.startPipeline("touch","/tmp/2")`

## scala.sys.process 包

使用时需 `import scala.sys.process._`。

### 操作符
```
grep 模式:
  ".*"\.!
  ".*"\.!!
  ".*"\.lineStream
  ".*"\.lazyLines
  ".*"\.run\s*\(
```
**风险：** 当外部参数可控时，在字符串后调用 `!`、`!!`、`run()` 等操作符或函数会导致命令注入。

### Process 对象
```
grep 模式:
  Process\s*\(\s*"
  Process\s*\(
  ".*"\.\#\#
  ".*"\.\#\|
```
**风险：** `Process("xxx").run()` 执行命令。`##` 和 `#|` 用于管道操作，参数可控时可注入。

### 字符串隐式转换
```
grep 模式:
  import\s+scala\.sys\.process\._
```
**注意：** 导入 `scala.sys.process._` 后，字符串会被隐式转换为可执行命令的对象。任何包含用户输入的字符串后跟 `!`、`!!`、`run()` 等操作符都是高风险 sink。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `sh -c` | `"sh -c 'process " + input + "'".!` |
| `bash -c` | `s"bash -c 'run $arg'".!!` |
| `perl -e` | `"perl -e 'print $input'".!` |

## Sink 前的字符串构造

```
grep 模式:
  s".*\$.*"               （s-string 插值）
  f".*\$.*"               （f-string 格式化）
  raw".*\$.*"             （raw-string）
  \+.*\+                  （字符串拼接）
  String\.format\s*\(
  StringBuilder.*append
```

当这些构造方式生成的字符串被传入命令执行操作符（`!`、`!!`、`run()`等）时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: Process\s*\([^)]*\.(sh|pl|py|lua)
grep 模式: ".*\.(sh|pl|py|lua)".!
```
