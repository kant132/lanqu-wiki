# 文件操作命令安全风险

覆盖命令：`rm`、`chmod`、`chown`、`mv`、`cp`、`cat`、`dd`、`ln`、`touch`、`truncate`、`shred`、`tee`、`install`、`find`

## 涉及的安全问题
- 操作任意文件（路径可控的读/写/删除/权限修改）
- 跨目录读写（路径穿越、符号链接逃逸）
- 命令注入（参数注入、find -exec）

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

### 命令注入 — find -exec
```bash
find . -name "$PATTERN" -exec $ACTION {} \;
# ACTION = "rm -rf"
```

### 命令注入 — 通配符展开
```bash
rm $USER_DIR/*
# 目录中存在名为 "-rf" 的文件 → rm 解析为参数
# 目录中存在 "--checkpoint-action=exec=id" → tar 执行命令

# 安全写法
rm -- "$USER_DIR"/*
```
