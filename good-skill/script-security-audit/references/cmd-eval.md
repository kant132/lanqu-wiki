# eval / exec / source / xargs / find 命令安全风险

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

### 跨脚本污点传播 — source 链
```bash
# scriptA.sh
source ./config.sh
eval "$ADMIN_CMD"
# 如果 config.sh 可被篡改，ADMIN_CMD 可执行任意命令
```
