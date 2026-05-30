# PHP Sink 点

PHP 代码中调用外部脚本解释器或执行命令的 sink 点。

## 命令执行函数

### exec()
```
grep 模式: \bexec\s*\(
```
**风险：** 执行外部程序，返回最后一行输出。第一个参数（command）经过 shell 解释。参数可控时为**高风险**。

### shell_exec()
```
grep 模式: \bshell_exec\s*\(
```
**风险：** 通过 shell 执行命令并返回完整输出。等同于反引号。参数可控时为**高风险**。

### system()
```
grep 模式: \bsystem\s*\(
```
**风险：** 执行外部程序并直接输出结果。命令经过 shell 解释。参数可控时为**高风险**。

### passthru()
```
grep 模式: \bpassthru\s*\(
```
**风险：** 执行外部程序并直接输出原始结果（适用于输出二进制数据）。参数可控时为**高风险**。

### proc_open()
```
grep 模式: \bproc_open\s*\(
```
**风险：** 执行命令并打开用于输入/输出的文件描述符。第一个参数经过 shell 解释。

### popen()
```
grep 模式: \bpopen\s*\(
```
**风险：** 打开到进程的管道。第一个参数经过 shell 解释。

### pcntl_exec()
```
grep 模式: \bpcntl_exec\s*\(
```
**风险：** 在当前进程空间执行新程序（不经过 shell），但第一个参数（path）可控时可执行任意程序。

## 反引号运算符

### 反引号 `` ` ``
```
grep 模式: `[^`]*`
```
**风险：** 等同于 `shell_exec()`，执行命令并返回输出。参数可控时为**高风险**。

## 代码执行函数

### eval()
```
grep 模式: \beval\s*\(
```
**风险：** 将字符串作为 PHP 代码执行。参数可控时为代码注入（不仅是命令注入）。

### assert()
```
grep 模式: \bassert\s*\(
```
**风险：** PHP 5 中，如果参数为字符串则作为 PHP 代码执行。PHP 7+ 已弃用此行为。

### preg_replace() + /e 修饰符
```
grep 模式: preg_replace\s*\(\s*['"]/.*\/e
```
**风险：** PHP 5 中 `/e` 修饰符使替换内容作为 PHP 代码执行。PHP 7+ 已移除。

### create_function()
```
grep 模式: \bcreate_function\s*\(
```
**风险：** 动态创建匿名函数，内部使用 `eval()`。PHP 8+ 已移除。

## 文件包含（间接代码执行）

### include / require / include_once / require_once
```
grep 模式:
  \binclude\s+
  \brequire\s+
  \binclude_once\s+
  \brequire_once\s+
```
**风险：** 如果文件路径包含用户输入（LFI/RFI），可导致任意代码执行。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `sh -c` | `exec("sh -c 'process " . $input . "'")` |
| `bash -c` | `system("bash -c 'run " . $arg . "'")` |
| `perl -e` | `shell_exec("perl -e 'print " . $input . "'")` |
| `python -c` | `exec("python -c '" . $cmd . "'")` |

## Sink 前的字符串构造

```
grep 模式:
  \.\s*\$                  （字符串拼接 . $var）
  sprintf\s*\(
  str_replace\s*\(
  preg_replace\s*\(
  \$\{.*\}                 （双引号内变量插值）
  implode\s*\(
  join\s*\(
```

当这些构造方式生成的字符串被传入 `exec()`、`system()`、`shell_exec()`、`passthru()`、`popen()` 或反引号时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: exec\s*\([^)]*\.(sh|pl|py|lua|php)
grep 模式: system\s*\([^)]*\.(sh|pl|py|lua|php)
grep 模式: shell_exec\s*\([^)]*\.(sh|pl|py|lua|php)
```

## PHP 特有的安全函数

审计时检查是否使用了以下安全函数（严格消毒）：
- `escapeshellarg()` — 为参数添加引号并转义内部引号
- `escapeshellcmd()` — 转义命令中的特殊字符
