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
