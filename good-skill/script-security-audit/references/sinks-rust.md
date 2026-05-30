# Rust Sink 点

Rust 代码中调用外部脚本解释器或执行命令的 sink 点。

## std::process::Command

### Command::new()
```
grep 模式:
  Command::new\s*\(
  std::process::Command::new\s*\(
```
**风险：** 只需关注第一个 String 参数：
1. 如果该参数完全可控，则可以注入。
2. 如果该参数是 `/bin/sh`（Linux）或 `cmd`（Windows）等 shell 解析器，且后续参数可控，则可以注入。
3. 如果第一个参数是 bat 或 sh 脚本文件，且后续参数可控，则需查看脚本如何使用可控参数来判断是否可注入。

### .arg() / .args()
```
grep 模式:
  \.arg\s*\(
  \.args\s*\(
```
**风险：** 向命令添加参数。如果命令是 shell 解析器（`sh -c`），参数可控则可注入。

### .output() / .status() / .spawn()
```
grep 模式:
  \.output\s*\(\s*\)
  \.status\s*\(\s*\)
  \.spawn\s*\(\s*\)
```
**风险：** 执行命令的终端方法。需结合 `Command::new()` 的参数来源判断风险。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `sh -c` | `Command::new("sh").arg("-c").arg(user_input)` |
| `bash -c` | `Command::new("bash").arg("-c").arg(&cmd)` |
| `perl -e` | `Command::new("perl").arg("-e").arg(code)` |
| `python -c` | `Command::new("python").arg("-c").arg(cmd)` |
| `python3 -c` | `Command::new("python3").arg("-c").arg(cmd)` |
| `lua -e` | `Command::new("lua").arg("-e").arg(script)` |

## Sink 前的字符串构造

```
grep 模式:
  format!\s*\(
  format_args!\s*\(
  \.push_str\s*\(
  \+\s*.*\+               （字符串拼接）
  String::from
  .to_string\(\)
  concat!\s*\(
```

当这些构造方式生成的字符串被传入 `Command::new("sh").arg("-c")` 或类似调用时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: Command::new\s*\([^)]*\.(sh|pl|py|lua)
```
