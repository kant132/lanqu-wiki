# Shell Sink 点

Shell 脚本（bash/sh/dash/zsh）中调用外部解释器或执行危险命令的 sink 点。

## 命令替换

### 反引号命令替换
```
grep 模式: `[^`]*`
```
**风险：** 反引号内的命令被执行，如果内容包含用户可控变量，可导致命令注入。

### $() 命令替换
```
grep 模式: \$\(
```
**风险：** 与反引号相同。嵌套使用时风险更高。

## eval

### eval 命令
```
grep 模式: \beval\s+
```
**风险：** 将参数作为 shell 命令执行。如果参数包含用户可控变量，这是**高风险**命令注入点。

## 解释器调用

### bash -c / sh -c
```
grep 模式:
  bash\s+-c\s+
  sh\s+-c\s+
  /bin/bash\s+-c\s+
  /bin/sh\s+-c\s+
```
**风险：** 当 `${cmd}` 参数完全可控时，输入任意命令即可被执行。部分可控时，利用 `;`、`|`、`||`、`&&`、`$()`、反引号等特殊字符拼接多命令执行语句也可注入成功。

### su -c / su --session-command
```
grep 模式:
  su\s+-\s+\w+\s+-c\s+
  su\s+-\s+\w+\s+--session-command\s+
```
**风险：** 以其他用户身份执行命令，参数可控时可注入。

### source / . (点命令)
```
grep 模式:
  \bsource\s+
  ^\.\s+
```
**风险：** 在当前 shell 中执行指定文件的内容。如果文件路径或内容可控，可执行任意命令。特别注意 source 配置文件时，配置值中包含花括号展开特征（如 `string {touch,/tmp/pwned}`）会被执行。

## Here Document

### 不带引号的 Here Document
```
grep 模式:
  <<\s*EOF
  <<\s*[A-Z_]+$
  <<\s*[A-Za-z_]+[^'"]$
```
**风险：** 当 EOF 标签不带引号时，here-doc 内容会进行变量替换、命令替换和算术展开。如果内容中包含用户可控变量，可导致命令注入。

**详细机制：**
- `<< EOF`（无引号）：父 shell 将 EOF 之间的内容当双引号字符串处理，展开 `${variable}`、`$(cmd)` 等
- 当 `<<` 前的 command 是 `bash`、`sh`、`eval`、`system` 等，且内容部分外部可控 → **命令注入**
- 示例：`filename=$(sleep${IFS}66)` 时，`bash << EOF` 中的 `echo ${filename}` 会展开并执行 sleep

### 带引号的 Here Document（低风险）
```
grep 模式:
  <<\s*'EOF'
  <<\s*"EOF"
  <<\s*\\EOF
```
**风险：** 带引号时禁用变量扩展（"所见即所得"），通常安全。但存在例外：
- 如果通过 `export` 将变量传递给子 Shell，子 shell 仍可展开变量 → **参数注入风险**
- `<< 'EOF'`、`<< "EOF"`、`<< \EOF` 三种写法等价，都禁用父 shell 展开

**参考：** GNU Bash Reference Manual 3.6.6 — "If any part of word is quoted, the lines in the here-document are not expanded."

## declare

### declare 命令
```
grep 模式: \bdeclare\s+
```
**风险：** 当参数可控时，可通过 `-x` 参数设置环境变量（如 `LD_PRELOAD`、`PATH`），结合恶意文件实现命令注入或方法劫持。

## flock

### flock -c 参数
```
grep 模式: flock\s+.*-c\s+
```
**风险：** `flock -ox filename -c "$cmd"` 形式中，`$cmd` 部分可控时可通过命令拼接符实现注入。

## 危险变量引用

### 位置参数直接使用
```
grep 模式:
  \$1[^0-9]
  \$2[^0-9]
  \$\{1\}
  \$\{2\}
  \$@
  \$\*
```
**风险：** 位置参数直接使用在命令中，如果来自外部输入且未经消毒，可导致注入。

### 环境变量直接使用
```
grep 模式: \$\{?[A-Z_]+\}?
```
**风险：** 环境变量可控时，在命令拼接中使用可导致注入。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `perl -e` | `perl -e "print $user_input"` |
| `python -c` | `python -c "import os; $cmd"` |
| `python3 -c` | `python3 -c "$script"` |
| `lua -e` | `lua -e "$code"` |
| `ruby -e` | `ruby -e "$code"` |
| `php -r` | `php -r "$code"` |
| `awk` | `awk "$pattern" file` |
| `node -e` | `node -e "$js_code"` |

## Sink 前的字符串构造

```
grep 模式:
  \$\{.*\}                （变量展开 ${var}）
  \$\(.*\)                （命令替换 $(cmd)）
  `[^`]*`                 （反引号命令替换）
  ".*\$.*"                （双引号内变量插值）
  \.\s*                   （.. 字符串连接 — 非 shell，但 awk/lua 中常见）
  printf\s+.*%s           （printf 格式化构造）
```

当这些构造方式生成的字符串被传入 `eval`、`bash -c`、`sh -c` 或反引号/`$()` 时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式:
  \./\w+\.sh
  bash\s+\w+\.sh
  sh\s+\w+\.sh
  source\s+\w+\.sh
  \.\s+\w+\.sh
  \./\w+\.(pl|py|lua|rb)
  perl\s+\w+\.pl
  python[3]?\s+\w+\.py
  lua\s+\w+\.lua
  ruby\s+\w+\.rb
```
