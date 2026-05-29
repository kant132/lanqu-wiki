# expect / TCL 命令安全风险

## 涉及的安全问题
- 命令注入（spawn/exec/system/eval/subst/open 管道）
- 上传下载（自动化 FTP/SCP/SFTP 文件传输）
- 操作任意文件（TCL exec 读取本地文件）
- 修改配置未校验参数（send 发送任意内容）

## 高危模式

### 命令注入 — spawn 执行命令
```tcl
spawn $USER_COMMAND
spawn ssh $USER_HOST
spawn ftp $USER_HOST
# USER_COMMAND/USER_HOST 可控 → 执行任意命令
```

### 命令注入 — send 发送内容
```tcl
send "$USER_INPUT\r"
send "$PASSWORD\r"
# USER_INPUT 可包含 TCL 特殊字符或 shell 转义序列
```

### 命令注入 — eval/exec/system
```tcl
eval $USER_CODE
eval "$USER_INPUT"
# 直接执行任意 TCL 代码

exec $USER_COMMAND
exec "$USER_CMD" > /tmp/output
# 执行任意系统命令

system "$USER_COMMAND"
```

### 命令注入 — subst 变量替换
```tcl
set result [subst $USER_TEMPLATE]
# USER_TEMPLATE = "[exec rm -rf /]" → 方括号内命令被执行
```

### 命令注入 — open 管道
```tcl
set fd [open "|$USER_COMMAND" r]
set fd [open "|$USER_CMD" w]
# 通过管道执行任意命令
```

### 上传下载 — 自动化 FTP/SCP/SSH
```tcl
# 自动化 FTP
spawn ftp $HOST
expect "Name*"
send "$USER\r"
expect "Password:"
send "$PASS\r"
expect "ftp>"
send "get $REMOTE_FILE\r"

# 自动化 SCP
spawn scp $LOCAL_FILE ${USER}@${HOST}:$REMOTE_PATH
expect "password:"
send "$PASS\r"

# 自动化 SSH 执行命令
spawn ssh ${USER}@${HOST} "$REMOTE_CMD"
expect "password:"
send "$PASS\r"

# 自动化 telnet
spawn telnet $HOST $PORT
expect "login:"
send "$USER\r"
expect "Password:"
send "$PASS\r"
expect "\\$"
send "$COMMAND\r"

# 自动化 sftp
spawn sftp ${USER}@${HOST}
expect "password:"
send "$PASS\r"
expect "sftp>"
send "put $LOCAL_FILE $REMOTE_PATH\r"
expect "sftp>"
send "get $REMOTE_FILE $LOCAL_PATH\r"
```

### 操作任意文件 — TCL exec 读取本地文件
```tcl
spawn ssh $HOST
expect "password:"
send "$PASS\r"
expect "\\$"
set result [exec cat /etc/shadow]
send "echo $result\r"
# 通过 TCL exec 读取本地敏感文件后通过 SSH 发送
```

### 修改配置未校验参数 — expect 匹配模式注入
```tcl
expect "$USER_PATTERN"
expect -re "$USER_REGEX"
# USER_PATTERN/USER_REGEX 可控 → 匹配任意内容，绕过安全检查
```

### 修改配置未校验参数 — 密码硬编码
```tcl
spawn ssh user@host
expect "password:"
send "P@ssw0rd123\r"
# 密码明文存储在 expect 脚本中
```
