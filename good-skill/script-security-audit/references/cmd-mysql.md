# mysql / psql / sqlite3 命令安全风险

## 涉及的安全问题
- SQL 注入（字符串拼接、动态表名、ORDER BY、LIKE、多语句）
- 命令注入（heredoc 注入）
- 修改配置未校验参数（通过 SQL 修改系统配置）

## 高危模式

### SQL 注入 — 字符串拼接
```bash
# mysql
mysql -e "SELECT * FROM users WHERE name='$USER_INPUT'"
# USER_INPUT = "' OR 1=1 --"

mysql -e "DELETE FROM logs WHERE date < '$USER_DATE'"

# psql
psql -c "SELECT * FROM users WHERE id = $USER_ID"
# USER_ID = "1; DROP TABLE users; --"

# sqlite3
sqlite3 db.sqlite "INSERT INTO logs VALUES ('$USER_MSG')"
# USER_MSG = "'); DROP TABLE logs; --"
```

### SQL 注入 — 动态表名/列名
```bash
mysql -e "SELECT * FROM $USER_TABLE"
mysql -e "SELECT $USER_COLUMN FROM users"
# 表名/列名无法参数化，必须白名单验证
```

### SQL 注入 — ORDER BY / LIMIT / LIKE
```bash
mysql -e "SELECT * FROM users ORDER BY $USER_ORDER"
# USER_ORDER = "(SELECT password FROM admin LIMIT 1)"

mysql -e "SELECT * FROM users WHERE name LIKE '%$USER_SEARCH%'"
# USER_SEARCH = "%' UNION SELECT password FROM admin --"
```

### SQL 注入 — 多语句执行
```bash
mysql -e "$USER_SQL"
# USER_SQL 可包含任意 SQL 语句（分号分隔）
```

### 命令注入 — heredoc 构建 SQL
```bash
mysql <<EOF
SELECT * FROM users WHERE name = '$USER_INPUT';
EOF
# USER_INPUT 可注入 shell 命令（heredoc 中变量展开）

# 安全写法
mysql <<'EOF'
SELECT * FROM users WHERE name = 'hardcoded';
EOF
```

### 命令注入 — sqlite3 内置命令

```bash
# sqlite3 内置 .system 和 .shell 可直接执行系统命令
sqlite3 /tmp/test.db '.system /bin/sh'
sqlite3 /tmp/test.db '.shell touch /tmp/pwned'

# 如果 sqlite3 执行的语句外部可控：
sqlite3 "$DB" "$USER_SQL"
# USER_SQL = ".system touch /tmp/pwned"
```

### 命令注入 — sqlite3 edit() 函数

```bash
# sqlite3 的 edit() 函数将第一个参数写入临时文件，
# 调用 $VISUAL 或 $EDITOR 环境变量指定的编辑器打开
# 如果编辑器环境变量可控，可实现命令执行
sqlite3 "$DB" "UPDATE t SET b=edit('','ls -al /root') WHERE a=0;"
# 内部执行: system("$VISUAL /tmp/tempfile")
# 如果 VISUAL="ls -al /root"，则执行 ls -al /root /tmp/tempfile

# 如果 SQL 语句或编辑器环境变量外部可控，可通过 edit() 执行任意命令
```

### 操作任意文件 — zsql DUMP 写文件

```bash
# zsql 客户端的 DUMP 命令可将表数据导出到任意文件
# 在数据库备份/恢复场景中常见

# 利用方式 1：创建表写入恶意命令，导出到 .bashrc
# SQL> CREATE TABLE test (name VARCHAR(2000));
# SQL> INSERT INTO test (name) VALUES ('touch /tmp/pwned');
# SQL> DUMP TABLE test INTO FILE '/home/user/.bashrc';

# 利用方式 2：直接 DUMP QUERY 写文件
# SQL> DUMP QUERY "select 'touch /tmp/pwned'" INTO FILE '/home/user/.bashrc';

# 如果 zsql 执行的 SQL 外部可控（如加载上传的 SQL 文件），可写任意文件 GetShell
```
