# Python Sink 点

Python 代码中调用外部脚本解释器或执行命令的 sink 点。

## subprocess 模块

### subprocess.run() / subprocess.call() / subprocess.check_call() / subprocess.check_output()
```
grep 模式:
  subprocess\.run\s*\(
  subprocess\.call\s*\(
  subprocess\.check_call\s*\(
  subprocess\.check_output\s*\(
```
**风险：** 当设置 `shell=True` 时，命令字符串传递给 `/bin/sh -c`，可导致命令注入。即使没有 `shell=True`，如果命令通过字符串拼接用户输入构建，也可能注入。

### subprocess.Popen()
```
grep 模式: subprocess\.Popen\s*\(
```
**风险：** 同上。`shell=True` 是主要危险指标。

### subprocess.getoutput() / subprocess.getstatusoutput()
```
grep 模式:
  subprocess\.getoutput\s*\(
  subprocess\.getstatusoutput\s*\(
```
**风险：** 这些函数**始终**使用 shell 执行。参数中的任何用户输入都是**高风险**。

## os 模块

### os.system()
```
grep 模式: os\.system\s*\(
```
**风险：** 始终将命令传递给 `sh -c`，等同于 C 的 `system()`。带用户输入时为**高风险**。

### os.popen()
```
grep 模式: os\.popen\s*\(
```
**风险：** 打开到/从 `sh -c` 的管道。带用户输入时为**高风险**。

### os.exec 系列
```
grep 模式:
  os\.execl\s*\(
  os\.execle\s*\(
  os\.execlp\s*\(
  os\.execv\s*\(
  os\.execve\s*\(
  os\.execvp\s*\(
  os\.execvpe\s*\(
```
**风险：** 不经过 shell 解释，除非目标是带 `-c` 的 `sh`/`bash`。

### os.spawn 系列
```
grep 模式: os\.spawn[lv]p?[e]?\s*\(
```
**风险：** 与 os.exec 系列类似，参数以数组形式传递。需关注参数来源和第一个参数是否为 shell 解析器。

## 内置函数

### eval()
```
grep 模式: \beval\s*\(
```
**风险：** 执行任意 Python 代码。如果参数包含用户输入，这是代码注入漏洞（不仅是命令注入）。

### exec()
```
grep 模式: \bexec\s*\(
```
**风险：** 与 `eval()` 相同，但用于多行代码块。

### compile()
```
grep 模式: \bcompile\s*\(
```
**注意：** 仅在编译后的代码被 `eval()` 或 `exec()` 执行时才有风险。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `bash -c` | `subprocess.run(["bash", "-c", f"process {user_input}"])` |
| `sh -c` | `os.system(f"sh -c 'run {arg}'")` |
| `perl -e` | `subprocess.call(f"perl -e '{code}'", shell=True)` |
| `python -c` | `os.system(f"python -c 'import os; {cmd}'")` |
| `lua -e` | `subprocess.run(f"lua -e '{script}'", shell=True)` |

## Sink 前的字符串构造

```
grep 模式:
  f".*\{.*\}.*"          （带插值的 f-string）
  .format\(
  %s.*%
  \+.*\+                 （字符串拼接）
  .join\(
```

当这些构造方式生成的命令字符串被传入带 `shell=True` 的 sink 或 `os.system()`/`os.popen()` 时，如果任何插值成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: subprocess\.\w+\s*\([^)]*\.(sh|pl|py|lua)
grep 模式: os\.system\s*\([^)]*\.(sh|pl|py|lua)
```
