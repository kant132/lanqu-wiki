# Ruby Sink 点

Ruby 代码中调用外部脚本解释器或执行命令的 sink 点。

## 命令执行方法

### system()
```
grep 模式: \bsystem\s*[\(\s]
```
**风险：** 默认使用 `/bin/sh` 解析，参数可控即可注入。

### exec()
```
grep 模式: \bexec\s*[\(\s]
```
**风险：** 替换当前进程执行命令，默认使用 shell 解析。参数可控即可注入。

### 反引号 `` ` ``
```
grep 模式: `[^`]*`
```
**风险：** 执行命令并返回输出，默认使用 `/bin/sh` 解析。参数可控即可注入。

### %x 字面量
```
grep 模式: %x[\(\[\{<]
grep 模式: %x\s
```
**风险：** 与反引号等价，执行命令并返回输出。参数可控即可注入。

## Open3 模块

### Open3.popen3 / popen2 / popen2e / capture2 / capture3
```
grep 模式:
  Open3\.popen3\s*\(
  Open3\.popen2\s*\(
  Open3\.popen2e\s*\(
  Open3\.capture2\s*\(
  Open3\.capture3\s*\(
```
**风险：** 创建子进程执行命令。如果命令字符串包含用户输入，可导致注入。

## IO 模块

### IO.popen()
```
grep 模式: IO\.popen\s*\(
```
**风险：** 打开到子进程的管道。参数可控时可注入。

### IO.read() / IO.write() / IO.binread() / IO.binwrite() / IO.foreach() / IO.readlines()
```
grep 模式:
  IO\.read\s*\(
  IO\.write\s*\(
  IO\.binread\s*\(
  IO\.binwrite\s*\(
  IO\.foreach\s*\(
  IO\.readlines\s*\(
```
**风险：** 当入参以 `|` 开头时，会使用 `/bin/sh -c` 解析器解析，可注入。例如 `IO.read("|malicious_command")`。

### open() / Kernel.open()
```
grep 模式:
  \bopen\s*\(
  Kernel\.open\s*\(
```
**风险：** 与 IO 文件操作函数相同，入参以 `|` 开头时使用 shell 解析器，可注入。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `sh -c` | `` `sh -c 'process #{input}'` `` |
| `bash -c` | `system("bash -c 'run #{arg}'")` |
| `perl -e` | `system("perl -e 'print #{input}'")` |
| `python -c` | `` `python -c '#{cmd}'` `` |

## Sink 前的字符串构造

```
grep 模式:
  #\{.*\}                 （字符串插值）
  \+.*\+                  （字符串拼接）
  %[\w]*[\(\[\{]          （%字面量格式化）
  sprintf\s*\(
  format\s*\(
```

当这些构造方式生成的字符串被传入 `system()`、`exec()`、反引号或 `%x` 时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: system\s*\([^)]*\.(sh|pl|py|lua|rb)
grep 模式: exec\s*\([^)]*\.(sh|pl|py|lua|rb)
```
