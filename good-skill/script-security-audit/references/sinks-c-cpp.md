# C/C++ Sink 点

C/C++ 代码中调用外部脚本解释器或执行命令的 sink 点。

## 命令执行函数

### system()
通过 `/bin/sh -c` 执行命令，整个命令字符串由 shell 解释。
```
grep 模式: system\s*\(
```
**风险：** 参数传递给 `sh -c`，字符串中任何用户可控内容都可导致命令注入。

### popen()
通过创建管道、fork 进程并调用 `/bin/sh -c` 来打开进程。
```
grep 模式: popen\s*\(
```
**风险：** 与 `system()` 相同 — 命令字符串经过 shell 解释。

### exec 系列函数
用新的进程映像替换当前进程映像。
```
grep 模式:
  execl\s*\(
  execlp\s*\(
  execle\s*\(
  execv\s*\(
  execvp\s*\(
  execvpe\s*\(
```
**风险：** 比 `system()` 低，因为参数以数组形式传递（不经过 shell 解释），除非第一个参数是 `sh`/`bash` 并带 `-c` 标志，这会重新启用 shell 解释。

### fork() + exec
常见模式：fork 子进程后 exec 执行命令。
```
grep 模式: fork\s*\(
```
**注意：** `fork()` 本身不是 sink，但需追踪到子进程分支（`if (pid == 0)` 之后）中的 `exec*()` 调用。

## 内联解释器调用模式

在任何 sink 点发现以下模式时，标记为**高风险**：

| 模式 | 示例 |
|------|------|
| `sh -c` | `system("sh -c 'process " + user_input + "'")` |
| `bash -c` | `popen("bash -c 'run " + arg + "'", "r")` |
| `perl -e` | `system("perl -e 'print " + input + "'")` |
| `python -c` | `execvp("python", ["python", "-c", cmd])` |
| `python3 -c` | `execvp("python3", ["python3", "-c", cmd])` |
| `lua -e` | `system("lua -e 'io.write(" + input + ")'")` |

## Sink 前的字符串构造

搜索构造后传入 sink 的字符串拼接操作：
```
grep 模式:
  sprintf\s*\(.*%s
  snprintf\s*\(.*%s
  strcat\s*\(
  strncat\s*\(
  asprintf\s*\(
  std::string.*\+
  fmt::format
```

当这些构造方式生成的字符串被传入 `system()`、`popen()` 或带 `sh -c` 的 `exec*()` 时，如果任何拼接成分是用户可控的，风险为**高**。

## 脚本文件引用

当 sink 调用脚本文件时（如 `system("./scripts/backup.sh")`），记录脚本路径并进入阶段三审计脚本本身。
```
grep 模式: system\s*\(\s*"[^"]*\.(sh|pl|py|lua)"
grep 模式: exec[lv]p?[e]?\s*\(.*\.(sh|pl|py|lua)
```
