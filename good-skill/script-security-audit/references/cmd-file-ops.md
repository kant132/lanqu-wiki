# 文件操作命令安全风险

覆盖命令：`rm`、`chmod`、`chown`、`mv`、`cp`、`cat`、`dd`、`ln`、`touch`、`truncate`、`shred`、`tee`、`install`、`find`、`usermod`、`adduser`

## 涉及的安全问题
- 操作任意文件（路径可控的读/写/删除/权限修改）
- 跨目录读写（路径穿越、符号链接逃逸）
- 命令注入（参数注入、find -exec）
- 文件权限劫持（通配符 + --reference）

## 高危模式

### 操作任意文件 — 删除
```bash
rm -rf "$USER_PATH"
rm "$USER_FILE"
# USER_PATH = "/" 或 USER_FILE = "/etc/passwd"

shred -u "$USER_FILE"
truncate -s 0 "$USER_FILE"
```

### 操作任意文件 — 权限修改
```bash
chmod $PERMS "$USER_FILE"
chown $OWNER "$USER_FILE"
# USER_FILE = "/etc/shadow"

# 参数注入
chmod $PERMS $FILE
# PERMS = "777" 且 FILE = "--reference=/etc/shadow /tmp/target"
```

### 操作任意文件 — 移动/覆盖
```bash
mv "$USER_SRC" "$USER_DST"
# USER_DST = "/etc/passwd" → 覆盖系统文件

install -m 755 "$USER_SRC" "$USER_DST"
```

### 操作任意文件 — 创建
```bash
touch "$USER_FILE"
```

### 跨目录读写 — 路径穿越
```bash
cat "/var/data/$USER_FILENAME"
# USER_FILENAME = "../../etc/shadow"

echo "$CONTENT" > "/var/data/$USER_FILENAME"
cp "$SOURCE" "/var/data/$USER_FILENAME"

# 间接控制
BASE_DIR="/var/data"
FILE_PATH="$BASE_DIR/$USER_INPUT"
rm "$FILE_PATH"
# USER_INPUT = "../../etc/important_config"
```

### 跨目录读写 — 符号链接逃逸
```bash
ln -s "$USER_TARGET" /opt/app/data/link
cat /opt/app/data/link
# USER_TARGET = "/etc/shadow"

cd "$USER_DIR" && cat config.ini
# USER_DIR = "/etc"
```

### 跨目录读写 — 重定向/tee
```bash
command > "$USER_OUTPUT_FILE"
command 2>> "$USER_LOG_FILE"
# 可覆盖任意文件（如 /etc/crontab）

echo "$DATA" | tee "$USER_FILE"
echo "$DATA" | tee -a "$USER_FILE"
```

### 跨目录读写 — dd
```bash
dd if="$USER_INPUT" of="$USER_OUTPUT"
# 可读写任意设备或文件
```

### 跨目录读写 — find 遍历
```bash
find "$USER_PATH" -type f -name "*.log"
# USER_PATH = "/" → 遍历整个文件系统
```

### 命令注入 — find -exec / -execdir

```bash
find . -name "$PATTERN" -exec $ACTION {} \;
# ACTION = "rm -rf"

# -exec 可执行任意命令，{} 替换为查找结果
find ./ -type f -name test.sh -exec echo "cat /etc/passwd" > aa.sh \;
find ./ -type f -name aa.sh -exec bash {} \;

# -execdir 在文件所在目录执行命令
find . -type f -name aa.sh -execdir touch cccc \;

# 如果 find 的 -name/-path 参数可控且后续拼接了 -exec：
find "$USER_DIR" -name "$USER_PATTERN" -exec bash {} \;
# USER_PATTERN = "*.sh" → 执行目录下所有 .sh 文件
```

### 操作任意文件 — find -delete

```bash
# -delete 删除查找到的所有文件
find . -type f -name "$PATTERN" -delete
# PATTERN = "*" → 删除当前目录所有文件
# PATTERN = "*.conf" → 删除所有配置文件

# 如果 -name 参数可控，可删除任意匹配的文件
find "$USER_DIR" -type f -name "$USER_PATTERN" -delete
```

### 命令注入 — 通配符展开
```bash
rm $USER_DIR/*
# 目录中存在名为 "-rf" 的文件 → rm 解析为参数

# 安全写法
rm -- "$USER_DIR"/*
```

### 文件权限劫持 — chown/chmod + 通配符 + --reference

```bash
# 当 chown/chmod 的 target 含通配符 * 时
chown someone:somegrp /d1/d2/*
chmod 644 /data/uploads/*

# 攻击者在目标目录创建：
# 文件名: --reference=attacker_file
# 文件名: attacker_file (攻击者拥有的文件)

# chown 展开后：
# chown someone:somegrp --reference=attacker_file attacker_file ...
# --reference 使所有文件的属主变为 attacker_file 的属主（攻击者）
# chmod 同理，--reference 使所有文件权限变为 attacker_file 的权限
```

### 操作任意文件 — usermod 文件移动

```bash
# usermod -d + -m 可移动用户 home 目录下的所有文件
# 第一次调用：将用户 home 改为攻击者控制的目录
usermod -d /tmp/evil_dir -m username

# 第二次调用：将文件移动到目标目录
usermod -d /root/target_dir -m username
# /tmp/evil_dir 下的文件被移动到 /root/target_dir

# 注意：-d 指定的目录必须不存在，否则 move 动作不生效
# 如果 usermod 参数可控，可实现任意文件移动
```

### 命令注入 — usermod/adduser 指定 shell

```bash
# 修改用户登录 shell
usermod -s /bin/bash username
# 如果 -s 参数可控，可指定恶意 shell

# adduser 同理
adduser --shell /bin/bash newuser
# 用户登录后加载指定的 shell/程序
```
