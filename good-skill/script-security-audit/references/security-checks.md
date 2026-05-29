# 跨脚本污点传播

当 sink 点调用脚本 A，脚本 A 内部又调用脚本 B 或外部命令时，追踪污点数据在脚本间的传播路径。

## 污点传播模式

**模式一：参数传递链**
```
宿主程序 → system("./scriptA.sh", user_input)
              ↓
scriptA.sh: ./scriptB.sh "$1"
              ↓
scriptB.sh: rm -rf "$1"    ← 污点到达危险操作
```
脚本 A 将参数透传给脚本 B，中间无任何过滤。审计时需要跟踪参数从 A 到 B 的传递。

**模式二：环境变量传递**
```
宿主程序: setenv("USER_DATA", user_input); system("./scriptA.sh")
              ↓
scriptA.sh: echo "$USER_DATA" | ./scriptB.sh
              ↓
scriptB.sh: mysql -e "SELECT * FROM $1"    ← 污点通过环境变量 + 参数到达 SQL
```
污点通过环境变量进入脚本 A，再通过管道/参数传递给脚本 B。

**模式三：文件中转**
```
宿主程序: write_file("/tmp/data", user_input); system("./scriptA.sh")
              ↓
scriptA.sh: DATA=$(cat /tmp/data); ./scriptB.sh "$DATA"
              ↓
scriptB.sh: curl "$1" | bash    ← 污点通过文件中转到达命令执行
```
污点先写入临时文件，脚本 A 读取后传递给脚本 B。

**模式四：source / eval 链**
```
宿主程序: system("./scriptA.sh")
              ↓
scriptA.sh: source ./config.sh
              ↓
config.sh: ADMIN_CMD="rm -rf /tmp/cache"
              ↓
scriptA.sh: eval "$ADMIN_CMD"    ← 如果被 source 的文件可被篡改
```
脚本 A source 了另一个文件，该文件的内容被 eval 执行。如果文件可被攻击者篡改，等同于命令注入。

**模式五：管道链**
```
宿主程序: system("./scriptA.sh", user_input)
              ↓
scriptA.sh: echo "$1" | grep pattern | ./scriptB.sh
              ↓
scriptB.sh: while read line; do curl "$line"; done    ← 污点通过管道到达网络请求
```
污点通过管道在多个命令/脚本间传递。

## 审计流程

对每个 sink 点调用的脚本，执行以下跨脚本追踪：

1. **识别脚本的外部调用：**
   - 脚本中是否调用其他脚本？（`./other.sh`、`bash other.sh`、`source other.sh`、`. other.sh`）
   - 脚本中是否通过 `exec`、`system`、反引号调用外部命令？

2. **追踪参数传递：**
   - 脚本接收的参数（`$1`、`$2`、`$@`）是否传递给下游脚本/命令？
   - 环境变量是否在下游脚本中被使用？
   - 是否通过临时文件传递数据？

3. **参数消毒检测（加载 `references/patterns-sanitization.md`）：**
   对每条污点传播路径，检查参数在使用前是否经过消毒：
   - **严格消毒**（白名单字符过滤、正则白名单验证、专业转义函数如 `shlex.quote`/`printf %q`、参数化传递、路径前缀验证）→ **终止该路径的传播分析**
   - **弱消毒**（黑名单过滤、简单引号包裹、长度限制）→ **继续传播分析**，但降低风险等级
   - **无消毒** → 继续传播分析，保持原风险等级

   消毒终止时，在报告中标注：
   ```
   消毒检测：scriptA.sh:15 对 $1 执行了严格白名单过滤 (tr -cd 'a-zA-Z0-9')
   传播状态：终止
   风险评定：低
   ```

4. **递归追踪下游脚本（仅对未被消毒终止的路径）：**
   - 读取下游脚本内容
   - 扫描下游脚本中的命令关键词，按需加载对应的安全检查参考文件（参见 SKILL.md 阶段四的按需加载表）
   - 追踪污点数据在下游脚本中的传播路径和最终到达的危险操作
   - 对下游脚本中的每条传播路径，同样执行参数消毒检测
   - 如果下游脚本又调用其他脚本且污点未被消毒终止，继续递归（设置最大递归深度为 3 层，避免无限循环）

5. **标记污点传播链：**
   在报告中记录完整的传播路径（含消毒终止点）：
   ```
   sink点 (file.c:42) → scriptA.sh:$1 (line 5) → [消毒: scriptA.sh:8 tr -cd 'a-zA-Z0-9'] → 传播终止
   sink点 (file.c:50) → scriptB.sh:$1 (line 3) → scriptC.sh:$1 (line 12) → rm -rf "$1"
   ```

## 递归深度控制

为避免无限递归（脚本 A 调用 B，B 调用 A），设置以下限制：
- 最大递归深度：3 层
- 已审计的脚本不重复审计（记录已审计文件路径）
- 循环调用时标记为"循环依赖"并停止深入

## 常见跨脚本污点场景

| 场景 | 传播路径 | 风险 |
|------|----------|------|
| 包装脚本透传 | A 接收参数直接传给 B | 取决于 B 的操作 |
| 配置加载 | A source 配置文件后 eval | 配置文件可篡改时高危 |
| 管道处理 | A 输出通过管道传给 B | B 对输入的处理方式决定风险 |
| 临时文件中转 | A 写 /tmp，B 读 /tmp | /tmp 可被其他用户篡改 |
| 环境变量传递 | 宿主设环境变量，A 读取后传给 B | 环境变量可被子进程继承 |
| here-document 生成 | A 用 here-doc 生成脚本后执行 | 变量展开可注入代码 |
