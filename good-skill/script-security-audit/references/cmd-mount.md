# mount / nfs / exportfs 命令安全风险

## 涉及的安全问题
- 命令注入（挂载选项注入）
- 跨目录读写（挂载任意路径、符号链接逃逸）
- 修改配置未校验参数（exports 文件修改、ID 映射注入）

## 高危模式

### 跨目录读写 — 挂载任意路径
```bash
# NFS 挂载 — 服务器/路径可控
mount -t nfs "$NFS_SERVER:$EXPORT_PATH" "$MOUNT_POINT"
# NFS_SERVER = "evil.com" → 挂载攻击者的 NFS 服务器
# EXPORT_PATH = "/" → 导出攻击者服务器上的根目录

# NFS 挂载后通过符号链接逃逸
cat "$MOUNT_POINT/link"
# NFS 共享中有 symlink: /share/link -> /etc/shadow
```

### 命令注入 — 挂载选项注入
```bash
mount -t nfs -o "$USER_OPTIONS" "$SERVER:$PATH" "$MOUNT"
# USER_OPTIONS = "rw,no_root_squash,vers=3"
# no_root_squash → 本地 root 在 NFS 上也是 root，可读写任意文件
```

### 修改配置未校验参数 — exports 文件修改
```bash
echo "$EXPORT_PATH $CLIENT_HOST($OPTIONS)" >> /etc/exports
exportfs -a
# EXPORT_PATH = "/etc" → 导出 /etc 给攻击者
# OPTIONS = "rw,no_root_squash" → 攻击者可读写 /etc
```

### 修改配置未校验参数 — NFSv4 ID 映射注入
```bash
mount -t nfs4 -o idmap_domain="$DOMAIN" "$SERVER:/" "$MOUNT"
# DOMAIN 可控 → 影响用户/组映射，可能导致权限提升
```

### 跨目录读写 — showmount 信息泄露
```bash
showmount -e "$USER_HOST"
# 可探测任意主机的 NFS 导出列表
```
