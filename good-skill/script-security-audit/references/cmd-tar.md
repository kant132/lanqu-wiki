# tar 命令安全风险

## 涉及的安全问题
- 命令注入（参数注入、通配符展开）
- 跨目录解压（路径穿越、绝对路径、符号链接、硬链接、设备文件）
- 跨目录读写（解压目标可控）
- 操作任意文件（覆盖系统文件）
- 完整性校验缺失（解压后直接执行）

## 高危模式

### 命令注入 — 参数注入
```bash
# 未加引号的变量展开 — tar 将 --checkpoint-action 解析为参数
tar czf backup.tar.gz $DIRECTORY
# DIRECTORY = "--checkpoint=1 --checkpoint-action=exec=rm -rf /"

# 通配符展开 — 目录中的恶意文件名被解析为参数
tar czf backup.tar.gz $USER_DIR/*
# 目录中存在文件名 "--checkpoint-action=exec=id"

# 安全写法
tar czf backup.tar.gz -- "$DIRECTORY"
```

### 跨目录解压 — 路径穿越
```bash
# 归档中包含 ../ 路径
tar xf "$USER_ARCHIVE"
# 归档成员: ../../etc/cron.d/backdoor → 写入系统目录

# tar -C 目标目录用户可控
tar xf archive.tar -C "$USER_DIR"
# USER_DIR = "/" → 解压到根目录

# 归档中包含绝对路径
tar xf "$USER_ARCHIVE"
# 归档成员: /etc/passwd → 覆盖系统文件
```

### 跨目录解压 — 符号链接/硬链接/设备文件
```bash
# 符号链接攻击
tar xzf archive.tar.gz -C /opt/app/
# 归档中包含 symlink -> /etc/shadow
cat /opt/app/symlink  # 读取 /etc/shadow

# 硬链接攻击
tar xzf archive.tar.gz
# 归档中包含 hardlink -> /etc/passwd（共享 inode）
echo "malicious" > /opt/app/hardlink  # 覆盖 /etc/passwd

# 设备文件
tar xzf archive.tar.gz
# 归档中包含 /dev/sda → 创建块设备
dd if=/opt/app/sda of=/tmp/dump  # 读取磁盘

# FIFO 文件
tar xzf archive.tar.gz
# 归档中包含 named pipe → 读取时阻塞（DoS）
```

### 完整性校验缺失 — 解压后直接执行
```bash
# 解压后执行归档中的脚本
tar xf "$USER_ARCHIVE" -C /opt/app/ && /opt/app/setup.sh
# 归档中 setup.sh 由攻击者控制

# 管道解压后执行
curl "$URL" | tar xz && bash setup.sh
```

### 命令注入 — 通配符展开写入恶意文件名

当 tar 命令的 target 含通配符 `*` 且目录可写时，攻击者可在目录中创建特殊文件名，被 shell 展开后作为 tar 的选项解析：

```bash
# 脚本中常见的危险写法
tar cvf backup.tar /data/uploads/*

# 攻击者在 /data/uploads/ 目录下创建以下文件：
# 文件名: --checkpoint=1
# 文件名: --checkpoint-action=exec=sh /tmp/evil.sh
# 文件名: evil.sh (内容为恶意命令)

# tar 展开 * 后实际执行：
# tar cvf backup.tar /data/uploads/--checkpoint=1 /data/uploads/--checkpoint-action=exec=sh\ /tmp/evil.sh ...
# --checkpoint-action 中的命令被执行

# 也可以直接在文件名中写入命令（无需引号）：
# 文件名: --checkpoint-action=exec=rm *
```

## 安全选项
```bash
tar xf archive.tar --no-absolute-names          # 禁止绝对路径
tar xf archive.tar --exclude='../*'             # 排除路径穿越
tar xf archive.tar --no-same-owner              # 不保留属主
tar xf archive.tar --no-same-permissions        # 不保留权限
tar xf archive.tar --keep-old-files             # 不覆盖已存在文件
tar xf archive.tar --one-file-system            # 限制在同一文件系统
tar czf backup.tar.gz -- "$DIRECTORY"           # -- 终止选项解析
```
