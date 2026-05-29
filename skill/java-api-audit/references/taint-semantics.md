# 污点语义模型

## 1. 污点传播规则

### 1.1 传播操作（污点保留）

以下操作不消除污点，输出仍为 tainted：

| 操作类型 | 代码模式 | 说明 |
|----------|----------|------|
| 字符串拼接 | `"prefix" + tainted + "suffix"` | 拼接后整体 tainted |
| 字符串方法 | `.trim()`, `.substring()`, `.replace()`, `.toLowerCase()`, `.toUpperCase()` | 变换形态但不消除危险字符 |
| 类型转换(宽化) | `String.valueOf(tainted)`, `tainted.toString()` | 仍为字符串 |
| 集合操作 | `list.add(tainted)`, `map.put(key, tainted)` | 污点存入集合，取出时仍 tainted |
| 赋值传递 | `String a = tainted; method(a);` | 变量名变但值不变 |
| 条件分支 | `if (cond) { sink(tainted); }` | 分支不影响污点本身 |
| 序列化 | `JSON.toJSONString(tainted)`, `objectMapper.writeValue(tainted)` | 序列化后仍 tainted |

### 1.2 消除操作（污点消除）

以下操作可消除污点，输出变为 untainted：

| 操作类型 | 代码模式 | 消除条件 | 确定性 |
|----------|----------|----------|--------|
| 数字解析 | `Integer.parseInt(tainted)`, `Long.parseLong(tainted)` | 解析成功则只能是数字 | DETERMINISTIC |
| 枚举转换 | `Enum.valueOf(MyEnum.class, tainted)` | 必须是合法枚举值 | DETERMINISTIC |
| UUID 生成 | `UUID.randomUUID().toString()` | 与输入无关 | DETERMINISTIC |
| 白名单查找 | `ALLOWED_VALUES.get(tainted)`, `switch(tainted)` 有限 case | 输出是预定义值 | DETERMINISTIC |
| 布尔判断 | `tainted.equals("fixed")`, `"constant".equals(tainted)` | 输出是 boolean | DETERMINISTIC |
| 长度截断 | `tainted.substring(0, Math.min(tainted.length(), 5))` | 仅当截断长度 < 最小 payload 长度 | HEURISTIC |

### 1.3 条件消除操作（上下文相关）

以下操作**可能**消除污点，取决于 Sink 类型：

| 操作 | 对 SQL | 对 HTML | 对 OS Cmd | 对 LDAP | 对 URL | 对文件路径 |
|------|--------|---------|-----------|---------|--------|-----------|
| `PreparedStatement` 参数化 | **消除** | N/A | N/A | N/A | N/A | N/A |
| `JPA Criteria API` | **消除** | N/A | N/A | N/A | N/A | N/A |
| `MyBatis #{}` | **消除** | N/A | N/A | N/A | N/A | N/A |
| `MyBatis ${}` | **不消除** | N/A | N/A | N/A | N/A | N/A |
| `HtmlUtils.htmlEscape()` | **不消除** | **消除** | **不消除** | **不消除** | **不消除** | **不消除** |
| `StringEscapeUtils.escapeHtml4()` | **不消除** | **消除** | **不消除** | **不消除** | **不消除** | **不消除** |
| `URLEncoder.encode()` | **不消除** | 部分 | **不消除** | **不消除** | **消除**(值部分) | **不消除** |
| `StringEscapeUtils.escapeSql()` | 部分(已废弃) | **不消除** | **不消除** | **不消除** | **不消除** | **不消除** |
| `Pattern.matches("^[a-zA-Z0-9]+$")` | **消除** | **消除** | **消除** | **消除** | **消除** | **消除** |
| `Pattern.matches("^.{1,100}$")` (仅长度) | **不消除** | **不消除** | **不消除** | **不消除** | **不消除** | **不消除** |
| `Paths.get(base, tainted).normalize()` | N/A | N/A | N/A | N/A | N/A | 部分(需验证 canonical path) |
| `ProcessBuilder.command("fixed", tainted)` | N/A | N/A | **不消除**(参数注入) | N/A | N/A | N/A |
| `Runtime.exec("cmd " + tainted)` | N/A | N/A | **不消除**(命令注入) | N/A | N/A | N/A |
| `LdapTemplate` 参数化查询 | N/A | N/A | N/A | **消除** | N/A | N/A |
| `DirContext.search` 字符串拼接 | N/A | N/A | N/A | **不消除** | N/A | N/A |

## 2. 消毒有效性评估矩阵

### 2.1 评估流程

```
对每个 (Source, Sink) 对:

1. 识别 Sink 类型（SQL/HTML/CMD/LDAP/URL/FILE）
2. 识别 Source→Sink 路径上所有消毒操作
3. 对每个消毒操作，查上方矩阵确认对当前 Sink 类型是否有效
4. 综合评估:
   - 所有消毒操作均对当前 Sink 有效 → SANITIZED
   - 存在对当前 Sink 无效的消毒 → NOT_SANITIZED（即使对其他 Sink 有效）
   - 消毒有效但可被绕过 → PARTIALLY_SANITIZED
```

### 2.2 常见错误判断

| 错误判断 | 正确判断 | 原因 |
|----------|----------|------|
| `htmlEscape` 防 SQL 注入 | **不防** | HTML 实体编码不影响 SQL 元字符 `'`, `"`, `;` |
| `URLEncoder.encode` 防 SQL 注入 | **不防** | URL 编码的 `%27` 在 SQL 上下文中不会被解码为 `'`，但某些中间件会二次解码 |
| `addslashes` 防 SQL 注入 | **部分防** | 对 MySQL 的 `\'` 有效，但对 GBK 宽字节注入无效 |
| `stripTags` 防 XSS | **部分防** | 可防 `<script>` 但不防属性注入 `onerror=` |
| `blacklist` 防 SQL 注入 | **不防** | 黑名单总有遗漏（如忘记 `/**/` 注释绕过） |
| `PreparedStatement` + 拼接 | **不防** | `"SELECT * FROM t WHERE id = " + pstmt` 仍然是拼接 |

## 3. Sink 上下文识别规则

### 3.1 SQL Sink 上下文

```
确定性判定:
  DETERMINISTIC: Statement.executeQuery/executeUpdate + 字符串拼接 → SQL注入确认
  DETERMINISTIC: PreparedStatement + setString/setInt → 安全（参数化）
  HEURISTIC:    PreparedStatement + 字符串拼接 SQL + setString → 需确认拼接部分是否含用户输入
  DETERMINISTIC: MyBatis ${} → SQL注入确认
  DETERMINISTIC: MyBatis #{} → 安全（参数化）
  HEURISTIC:    JPA @Query + SpEL :#{#param} → 需确认 SpEL 表达式是否安全
  DETERMINISTIC: JPA Criteria API → 安全
```

### 3.2 文件路径 Sink 上下文

```
确定性判定:
  DETERMINISTIC: new File(userInput) → 路径穿越确认
  DETERMINISTIC: new File(baseDir, userInput) 无 normalize → 路径穿越确认
  DETERMINISTIC: new File(baseDir, UUID) → 安全
  HEURISTIC:    new File(baseDir, userInput) + canonical path 校验 → 需确认校验是否在写入前执行
  HEURISTIC:    new File(baseDir, userInput) + 后缀追加 → 需确认是否可绕过（如 null byte）
```

### 3.3 命令执行 Sink 上下文

```
确定性判定:
  DETERMINISTIC: Runtime.exec("cmd " + userInput) → 命令注入确认
  DETERMINISTIC: ProcessBuilder("fixed_cmd", userInput) → 参数注入（取决于命令如何处理参数）
  HEURISTIC:    ProcessBuilder(userInput) → 需确认 userInput 是否包含空格/特殊字符
  DETERMINISTIC: ProcessBuilder("cmd", "-c", "fixed " + userInput) → 命令注入确认
```

## 4. 置信度标注规范

每个 Source→Sink 链路必须标注置信度：

| 置信度 | 含义 | 判定条件 |
|--------|------|----------|
| CONFIRMED | 漏洞确认 | 所有步骤均为 DETERMINISTIC，污点传播链完整无断裂 |
| LIKELY | 高度可疑 | 关键步骤为 DETERMINISTIC，但存在 1 个 HEURISTIC 步骤 |
| POSSIBLE | 可能存在 | 多个 HEURISTIC 步骤，或存在 SUBJECTIVE 判断 |
| FALSE_POSITIVE | 误报 | 存在有效的上下文敏感消毒，或污点链断裂 |

输出格式：
```
置信度: CONFIRMED
判定依据:
  Step 1 (DETERMINISTIC): @RequestParam → 用户可控
  Step 2 (DETERMINISTIC): 直接传递，无消毒
  Step 3 (DETERMINISTIC): 字符串拼接到 SQL
  Step 4 (DETERMINISTIC): Statement.executeQuery 执行
  消毒评估: 无消毒操作 → NOT_SANITIZED
```
