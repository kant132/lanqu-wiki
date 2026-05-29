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
