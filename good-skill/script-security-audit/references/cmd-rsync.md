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

### 完整性校验缺失 — SSH 主机验证绕过
```bash
rsync -e "ssh -o StrictHostKeyChecking=no" "$SRC" "$HOST:$DST"
rsync -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$SRC" "$HOST:$DST"
```
