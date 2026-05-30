# NodeJS Sink 点

NodeJS 代码中调用外部脚本解释器或执行命令的 sink 点。

## child_process 模块

### child_process.exec() / execSync()
```
grep 模式:
  child_process\.exec\s*\(
  child_process\.execSync\s*\(
  \bexec\s*\(
  \bexecSync\s*\(
```
**风险：** 命令字符串传递给 `/bin/sh -c`（Linux）或 `cmd.exe`（Windows）。参数中的任何用户输入都是**高风险**。

### child_process.execFile() / execFileSync()
```
grep 模式:
  child_process\.execFile\s*\(
  child_process\.execFileSync\s*\(
  \bexecFile\s*\(
  \bexecFileSync\s*\(
```
**风险：** 第一个参数（可执行文件路径）可控时需要关注。后续参数以数组形式传递，不经过 shell 解释，但如果第一个参数是 bat/sh 脚本，后续参数仍可能被 shell 解析。

### child_process.spawn() / spawnSync()
```
grep 模式:
  child_process\.spawn\s*\(
  child_process\.spawnSync\s*\(
  \bspawn\s*\(
  \bspawnSync\s*\(
```
**风险：** 参数以数组形式传递。但如果设置了 `shell: true` 选项，参数将经过 shell 解释。第一个参数为 `sh`/`bash`/`cmd` 时也需关注。

### child_process.fork()
```
grep 模式:
  child_process\.fork\s*\(
  \bfork\s*\(
```
**风险：** 启动新的 Node 进程。如果 `modulePath` 或 `args` 可控，可能加载恶意脚本。`execArgv` 参数可控时可注入 `--eval`、`--require` 等危险参数。

## Electron (shell 模块)

### shell.openExternal()
```
grep 模式:
  shell\.openExternal\s*\(
  openExternal\s*\(
```
**风险：** 在系统默认应用中打开 URL/文件。如果参数可控，可通过 `file:` 协议执行本地程序，或通过 SMB/网络共享加载远程恶意程序。

### shell.openPath()
```
grep 模式:
  shell\.openPath\s*\(
  openPath\s*\(
```
**风险：** 与 `openExternal` 类似，以系统默认方式打开指定路径。参数可控时可执行任意文件。

## Node 进程参数注入

当 Node 进程启动参数可控时，以下参数可导致命令注入：

| 参数 | 风险 |
|------|------|
| `-e` / `--eval` | 直接执行任意 JavaScript 代码 |
| `-p` / `--print` | 执行 JavaScript 并打印结果 |
| `-r` / `--require` | 预加载模块，结合 `/proc/self/environ` 或 `/proc/self/cmdline` 可 RCE |
| `--import` | 导入模块，风险同 `--require` |
| `--inspect-brk` | 开启调试端口，可通过调试协议执行任意命令 |
| `NODE_OPTIONS` 环境变量 | 可注入上述任意参数 |

**原型链污染风险：** Node 某些版本中，`child_process.spawn` 的 `options` 对象存在原型链污染问题，攻击者可通过 `__proto__` 注入 `NODE_OPTIONS`、`env`、`argv0` 等参数实现 RCE。已在 v20.5.1+ 等版本修复。

## 内联解释器调用模式

| 模式 | 示例 |
|------|------|
| `sh -c` | `exec("sh -c 'process " + input + "'")` |
| `bash -c` | `execSync("bash -c 'run " + arg + "'")` |
| `perl -e` | `exec("perl -e 'print " + input + "'")` |
| `python -c` | `spawn("python", ["-c", cmd])` |
| `python3 -c` | `spawn("python3", ["-c", cmd])` |
| `lua -e` | `exec("lua -e 'io.write(" + input + ")'")` |
| `node -e` | `exec("node -e 'require(\"child_process\").execSync(\"" + cmd + "\")'")` |

## Sink 前的字符串构造

```
grep 模式:
  `\$\{.*\}`              （模板字符串插值）
  \+.*\+                  （字符串拼接）
  util\.format\s*\(
  String\.raw
  .concat\s*\(
  .replace\s*\(
```

当这些构造方式生成的字符串被传入 `exec()`/`execSync()` 或带 `shell: true` 的 `spawn()` 时，如果任何成分是用户可控的，风险为**高**。

## 脚本文件引用

```
grep 模式: exec\s*\([^)]*\.(sh|pl|py|lua|js|bat|cmd)
grep 模式: spawn\s*\([^)]*\.(sh|pl|py|lua|js|bat|cmd)
grep 模式: execFile\s*\([^)]*\.(sh|pl|py|lua|js|bat|cmd)
```
