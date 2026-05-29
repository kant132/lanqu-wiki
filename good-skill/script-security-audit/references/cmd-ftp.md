# ftp / lftp 命令安全风险

## 涉及的安全问题
- 命令注入（here-document 注入、参数注入）
- 上传下载（任意文件上传/下载、SSRF、协议利用）
- 跨目录读写（远程/本地路径可控）
- 修改配置未校验参数（.netrc 凭证写入）

## 高危模式

### 命令注入 — here-document 注入
```bash
ftp -n "$HOST" <<EOF
user $USERNAME $PASSWORD
cd $REMOTE_DIR
get $REMOTE_FILE /local/data/
put /local/upload/$FILE
EOF
# 所有变量可控 → 命令注入 + 凭证泄露 + 任意文件操作
```

### 上传下载 — FTP 批处理
```bash
# Windows FTP 批处理
echo "open $HOST" > /tmp/ftp_batch
echo "user $USER $PASS" >> /tmp/ftp_batch
echo "get $FILE" >> /tmp/ftp_batch
ftp -s:/tmp/ftp_batch

# lftp 用户可控
lftp -u "$USER,$PASS" "ftp://$HOST" -e "get $FILE; quit"
lftp -c "open ftp://$HOST && mirror $REMOTE_DIR $LOCAL_DIR"
```

### 修改配置未校验参数 — .netrc 凭证写入
```bash
echo "machine $HOST login $USER password $PASS" >> ~/.netrc
# HOST 可控 → 可写入任意机器的凭证
```

### 上传下载 — FTP 代理/跳转
```bash
ftp "$PROXY_HOST" <<EOF
user $TARGET_USER@$TARGET_HOST $PASS
EOF
# 通过 FTP 代理访问内网主机
```
