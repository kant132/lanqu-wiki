# Lua Sink 点

Lua 代码中调用外部脚本解释器或执行命令的 sink 点。

## os 模块

### os.execute()
```
grep 模式: os\.execute\s*\(
```
**风险：** 通过系统 shell 执行命令（等同于 C 的 `system()`）。参数可控则存在注入。

## io 模块

### io.popen()
```
grep 模式: io\.popen\s*\(
```
**风险：** 通过 shell 启动进程并返回文件句柄。第一个参数（command）可控则存在注入。第二个参数为模式（"r" 或 "w"）。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `sh -c` | `os.execute("sh -c 'process " .. input .. "'")` |
| `bash -c` | `os.execute("bash -c 'run " .. arg .. "'")` |
| `perl -e` | `os.execute("perl -e 'print " .. input .. "'")` |
| `python -c` | `os.execute("python -c '" .. cmd .. "'")` |

## Sink 前的字符串构造

```
grep 模式:
  \.\.\s*                 （.. 字符串连接运算符）
  string\.format\s*\(
  table\.concat\s*\(
```

当这些构造方式生成的字符串被传入 `os.execute()` 或 `io.popen()` 时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: os\.execute\s*\([^)]*\.(sh|pl|py|lua)
grep 模式: io\.popen\s*\([^)]*\.(sh|pl|py|lua)
```
