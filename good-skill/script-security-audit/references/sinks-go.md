# Go Sink 点

Go 代码中调用外部脚本解释器或执行命令的 sink 点。

## os/exec 包

### exec.Command()
```
grep 模式: exec\.Command\s*\(
```
**风险：** 参数直接传递（不经过 shell 解释）。但如果第一个参数是带 `-c` 的 `sh`/`bash`，或参数由用户输入构建且未经验证，则可能注入。

### exec.CommandContext()
```
grep 模式: exec\.CommandContext\s*\(
```
**风险：** 与 `exec.Command()` 相同，但支持 context。

## syscall 包

### syscall.Exec()
```
grep 模式: syscall\.Exec\s*\(
```
**风险：** 直接传递参数数组（不经过 shell），风险与 `exec.Command()` 类似。需关注参数来源。

### syscall.ForkExec()
```
grep 模式: syscall\.ForkExec\s*\(
```
**风险：** fork 后 exec，参数以数组形式传递。需关注参数来源和第一个参数是否为 shell 解析器。

### syscall.StartProcess()
```
grep 模式: syscall\.StartProcess\s*\(
```
**风险：** 底层进程创建接口，参数以数组形式传递。需关注参数来源。

## os 包

### os.StartProcess()
```
grep 模式: os\.StartProcess\s*\(
```
**风险：** 与 `syscall.StartProcess()` 类似，底层进程创建接口。需关注参数来源。

## 内联解释器调用模式

以下模式在 Go 代码中标记为**高风险**：

| 模式 | 示例 |
|------|------|
| `exec.Command("sh", "-c", ...)` | `exec.Command("sh", "-c", "process "+userInput)` |
| `exec.Command("bash", "-c", ...)` | `exec.Command("bash", "-c", fmt.Sprintf("run %s", arg))` |
| `exec.Command("perl", "-e", ...)` | `exec.Command("perl", "-e", code)` |
| `exec.Command("python", "-c", ...)` | `exec.Command("python", "-c", cmd)` |
| `exec.Command("python3", "-c", ...)` | `exec.Command("python3", "-c", cmd)` |
| `exec.Command("lua", "-e", ...)` | `exec.Command("lua", "-e", script)` |

## Sink 前的字符串构造

```
grep 模式:
  fmt\.Sprintf\s*\(
  fmt\.Sprint[f]?\s*\(
  strings\.Join\s*\(
  \+\s*.*\+               （字符串拼接）
  strings\.Builder
  strings\.Replace
```

当这些构造方式生成的字符串被传入 `exec.Command("sh", "-c", ...)` 或类似调用时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: exec\.Command\s*\([^)]*\.(sh|pl|py|lua)
grep 模式: exec\.CommandContext\s*\([^)]*\.(sh|pl|py|lua)
```
