# 跨语言调用 / bash -c 命令安全风险

Shell 脚本中调用其他语言解释器（perl、python、lua、ruby、php、awk）或使用 `bash -c` / `sh -c` 内联执行。

## 涉及的安全问题
- 命令注入（变量插值导致目标语言代码注入）
- 跨语言上下文逃逸（利用目标语言特性执行系统命令）
- 跨脚本污点传播（污点从 shell 上下文传播到目标语言上下文）

## 高危模式

### bash -c / sh -c — 内联 shell 执行
```bash
# bash -c 带变量插值
bash -c "process $USER_INPUT"
# USER_INPUT = "; rm -rf /" → 命令注入

# sh -c 带变量插值
sh -c "echo $USER_DATA"
# USER_DATA = "$(whoami)" → 命令替换执行

# 格式化字符串构建命令
CMD=$(printf "bash -c 'convert %s %s'" "$INPUT" "$OUTPUT")
eval "$CMD"
# INPUT/OUTPUT 可控 → 注入任意命令

# 嵌套 shell 执行
bash -c "bash -c 'echo $USER_INPUT'"
# 双重解释，更容易绕过转义

# bash -c 执行脚本内容
bash -c "$(cat /tmp/script.sh)"
# 如果脚本可被篡改 → 执行任意代码
```

### perl -e — 内联 Perl 执行
```bash
# perl -e 带变量插值
perl -e "print '$USER_INPUT'"
# USER_INPUT = "'; system('rm -rf /'); print '" → Perl 代码注入

# perl -e 处理数据
perl -e "while(<STDIN>){s/$PATTERN/$REPLACE/g; print}"
# PATTERN/REPLACE 可控 → Perl 正则代码执行（/e 标志）

# perl -e 执行系统命令
perl -e "system('$USER_CMD')"
# USER_CMD 可控 → 执行任意命令

# perl -e 文件操作
perl -e "open(F,'>$USER_FILE'); print F '$USER_DATA'"
# USER_FILE/USER_DATA 可控 → 写入任意文件

# perl -ne / -pe 带变量
perl -ne "print if /$USER_PATTERN/" file.txt
# USER_PATTERN 可控 → 正则注入

# perl 执行脚本文件
perl "$USER_SCRIPT"
# USER_SCRIPT 可控 → 执行任意 Perl 脚本
```

### python -c / python3 -c — 内联 Python 执行
```bash
# python -c 带变量插值
python -c "print('$USER_INPUT')"
# USER_INPUT = "'); import os; os.system('rm -rf /'); print('" → Python 代码注入

# python3 -c 带 f-string
python3 -c "import sys; print(f'Hello {$USER_INPUT}')"
# USER_INPUT = "os.system('id')" → 代码注入

# python -c 执行系统命令
python -c "import os; os.system('$USER_CMD')"
# USER_CMD 可控 → 执行任意命令

# python -c 文件操作
python -c "open('$USER_FILE','w').write('$USER_DATA')"
# USER_FILE/USER_DATA 可控 → 写入任意文件

# python -c 网络操作
python -c "import urllib.request; urllib.request.urlretrieve('$URL','/tmp/file')"
# URL 可控 → SSRF / 下载任意文件

# python 执行脚本文件
python "$USER_SCRIPT"
python3 "$USER_SCRIPT" "$USER_ARG"
# USER_SCRIPT 可控 → 执行任意 Python 脚本
```

### lua -e — 内联 Lua 执行
```bash
# lua -e 带变量插值
lua -e "print('$USER_INPUT')"
# USER_INPUT = "'); os.execute('rm -rf /'); print('" → Lua 代码注入

# lua -e 执行系统命令
lua -e "os.execute('$USER_CMD')"
# USER_CMD 可控 → 执行任意命令

# lua -e 文件操作
lua -e "io.open('$USER_FILE','w'):write('$USER_DATA')"
# USER_FILE/USER_DATA 可控 → 写入任意文件

# lua 执行脚本文件
lua "$USER_SCRIPT"
# USER_SCRIPT 可控 → 执行任意 Lua 脚本
```

### ruby -e — 内联 Ruby 执行
```bash
# ruby -e 带变量插值
ruby -e "puts '$USER_INPUT'"
# USER_INPUT = "'; system('rm -rf /'); puts '" → Ruby 代码注入

# ruby -e 执行系统命令
ruby -e "system('$USER_CMD')"
ruby -e "exec('$USER_CMD')"
ruby -e "\`$USER_CMD\`"
# USER_CMD 可控 → 执行任意命令

# ruby -e 文件操作
ruby -e "File.write('$USER_FILE','$USER_DATA')"
# USER_FILE/USER_DATA 可控 → 写入任意文件

# ruby 执行脚本文件
ruby "$USER_SCRIPT"
# USER_SCRIPT 可控 → 执行任意 Ruby 脚本
```

### php -r — 内联 PHP 执行
```bash
# php -r 带变量插值
php -r "echo '$USER_INPUT';"
# USER_INPUT = "'; system('rm -rf /'); echo '" → PHP 代码注入

# php -r 执行系统命令
php -r "system('$USER_CMD');"
php -r "exec('$USER_CMD');"
php -r "passthru('$USER_CMD');"
php -r "shell_exec('$USER_CMD');"
# USER_CMD 可控 → 执行任意命令

# php -r 文件操作
php -r "file_put_contents('$USER_FILE','$USER_DATA');"
# USER_FILE/USER_DATA 可控 → 写入任意文件

# php 执行脚本文件
php "$USER_SCRIPT"
# USER_SCRIPT 可控 → 执行任意 PHP 脚本
```

### awk — 文本处理中的代码注入
```bash
# awk 带变量插值（作为程序代码）
awk "/$USER_PATTERN/ {print}" file.txt
# USER_PATTERN 可控 → awk 代码注入

# awk -v 变量赋值（相对安全，但仍需注意）
awk -v pat="$USER_PATTERN" '$0 ~ pat {print}' file.txt
# -v 赋值不执行代码，但如果 pat 用于正则匹配仍需注意

# awk 执行系统命令
awk "{system('$USER_CMD')}" file.txt
# USER_CMD 可控 → 执行任意命令

# awk 执行任意代码
awk "$USER_AWK_PROGRAM" file.txt
# USER_AWK_PROGRAM 可控 → 执行任意 awk 代码

# awk 文件操作
awk "BEGIN{print \"$USER_DATA\" > \"$USER_FILE\"}"
# USER_FILE/USER_DATA 可控 → 写入任意文件
```

### node -e — 内联 Node.js 执行
```bash
# node -e 带变量插值
node -e "console.log('$USER_INPUT')"
# USER_INPUT = "'); require('child_process').execSync('rm -rf /'); console.log('" → JS 代码注入

# node -e 执行系统命令
node -e "require('child_process').execSync('$USER_CMD')"
# USER_CMD 可控 → 执行任意命令

# node 执行脚本文件
node "$USER_SCRIPT"
# USER_SCRIPT 可控 → 执行任意 JS 脚本
```

## 跨语言注入的核心原理

所有跨语言调用的注入原理相同：
1. Shell 变量在传递给目标解释器之前被展开
2. 展开后的字符串成为目标语言代码的一部分
3. 攻击者通过构造变量值，闭合原有语法结构，注入目标语言代码
4. 目标语言解释器执行注入的代码

**通用注入模式：**
```bash
# 原始代码
<interpreter> -<flag> "<code>'$USER_INPUT'<code>"

# 攻击者构造
USER_INPUT = "'<close>; <malicious_code>; <open>'"

# 展开后
<interpreter> -<flag> "<code>'<close>'; <malicious_code>; <open>'<code>"
```

## 检查流程

1. 识别脚本中所有跨语言调用：`bash -c`、`sh -c`、`perl -e`、`python -c`、`python3 -c`、`lua -e`、`ruby -e`、`php -r`、`awk`、`node -e`
2. 检查是否有变量插值进入目标语言代码
3. 如果有插值，检查是否经过目标语言的转义（而非 shell 转义）
4. 检查目标语言代码中是否调用了危险函数（system、exec、open 等）
5. 追踪污点传播：shell 变量 → 目标语言变量 → 目标语言危险函数
