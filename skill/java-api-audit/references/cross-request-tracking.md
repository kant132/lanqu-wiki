# 跨请求污点追踪

## 1. 追踪模型

传统 Source→Sink 追踪局限于单次 HTTP 请求。以下模式需要跨请求追踪：

| 模式 | 存储介质 | 写入请求 | 读取请求 | 漏洞类型 |
|------|----------|----------|----------|----------|
| 存储型 XSS | DB/缓存 | POST /comment (存入) | GET /comments (渲染) | Stored XSS |
| 二阶 SQL 注入 | DB | POST /register (存入) | GET /profile (读出拼接SQL) | 2nd-order SQLi |
| Session 污染 | HttpSession | POST /search (存入session) | GET /result (从session读取使用) | Session-based attack |
| 缓存投毒 | Redis/Caffeine | POST /api (写入缓存) | GET /api (读取缓存渲染) | Cache poisoning |
| 文件持久化 | 文件系统 | POST /upload (写入文件) | GET /download (读取文件) | 任意文件读取 |

## 2. 追踪方法

### 2.1 Session 追踪

```
扫描目标:
  - HttpSession.setAttribute(key, taintedValue)  → 标记 session[key] 为 tainted
  - HttpSession.getAttribute(key)                → 若 session[key] 为 tainted，则输出 tainted
  - @SessionAttribute / @SessionAttributes       → Spring MVC session 绑定
  - WebUtils.setSessionAttribute()               → Spring 工具类

追踪步骤:
  1. 在所有 Controller 中 grep: setAttribute / setSessionAttribute
  2. 对每个 setAttribute，检查 value 是否来自 Source（@RequestParam 等）
  3. 若 tainted → 记录 (session_key, source_endpoint, source_param)
  4. 在所有 Controller 中 grep: getAttribute / getSessionAttribute
  5. 对每个 getAttribute(key)，检查 key 是否在 tainted session_keys 中
  6. 若匹配 → 追踪 getAttribute 返回值到 Sink
```

### 2.2 数据库存储追踪

```
扫描目标:
  - JPA Repository.save(entity)  → entity 字段若 tainted，则 DB 记录 tainted
  - JdbcTemplate.update/execute  → INSERT/UPDATE 参数若 tainted，则 DB 记录 tainted
  - MyBatis insert/update        → 同上

追踪步骤:
  1. 识别所有写入操作（INSERT/UPDATE）:
     - grep: repository.save / .update( / .insert( / saveAndFlush
     - 检查写入的 entity/参数是否包含 tainted 字段
  2. 建立 tainted 表/列清单:
     - (table_name, column_name, source_endpoint, source_param)
  3. 识别所有读取操作（SELECT）:
     - grep: repository.find / .get / .query / .select
     - 检查是否读取了 tainted 表/列
  4. 追踪读取结果到 Sink:
     - 读取的 tainted 值是否被拼接到 SQL/HTML/命令中
     - 读取的 tainted 值是否被渲染到模板中（th:text vs th:utext）
```

### 2.3 缓存追踪

```
扫描目标:
  - @Cacheable / @CachePut          → Spring Cache 注解
  - RedisTemplate.opsForValue().set → Redis 写入
  - CacheManager.getCache().put     → 缓存写入

追踪步骤:
  1. 识别缓存写入:
     - @CachePut 的方法返回值是否包含 tainted 数据
     - RedisTemplate.set 的 value 是否 tainted
  2. 识别缓存读取:
     - @Cacheable 的方法是否直接返回缓存值到响应
     - RedisTemplate.get 的返回值是否到达 Sink
  3. 评估缓存键是否可被攻击者控制（缓存投毒）
```

### 2.4 文件系统追踪

```
扫描目标:
  - file.transferTo(dest)     → 文件写入
  - Files.write(path, bytes)  → 文件写入
  - new FileInputStream(file) → 文件读取
  - Files.readAllBytes(path)  → 文件读取

追踪步骤:
  1. 识别文件写入:
     - 文件名/路径是否来自用户输入
     - 文件内容是否来自用户输入
  2. 识别文件读取:
     - 读取路径是否来自用户输入
     - 读取的内容是否到达 Sink
  3. 交叉验证:
     - 写入的文件是否可被另一个端点读取
     - 读取路径是否可穿越到敏感目录
```

## 3. 输出格式

```markdown
### 跨请求污点链路

**链路 ID**: XREQ-001
**漏洞类型**: 存储型 XSS
**置信度**: CONFIRMED / LIKELY / POSSIBLE

**写入端点**:
  端点: POST /comments
  Source: @RequestBody String content
  存储操作: commentRepository.save(comment) → comments 表 content 列
  位置: CommentController.java:45 → CommentRepository.save():12

**读取端点**:
  端点: GET /posts/{id}/comments
  读取操作: commentRepository.findByPostId(id) → 返回 List<Comment>
  Sink: th:utext="${comment.content}" (Thymeleaf 未转义渲染)
  位置: PostController.java:78 → comments.html:23

**完整链路**:
  POST /comments → @RequestBody content → CommentRepository.save() → [DB: comments.content]
  → CommentRepository.findByPostId() → th:utext 渲染 → Stored XSS

**PoC**:
  写入: curl -X POST /comments -d '{"content":"<script>alert(1)</script>"}'
  触发: curl /posts/1/comments → 响应中包含未转义的 <script> 标签
```

## 4. 确定性标注

| 步骤 | 确定性 | 说明 |
|------|--------|------|
| grep setAttribute/getAttribute | DETERMINISTIC | 正则匹配 |
| 判断 setAttribute 值是否 tainted | HEURISTIC | 需追踪值的来源 |
| grep repository.save/find | DETERMINISTIC | 正则匹配 |
| 判断 save 的 entity 字段是否 tainted | HEURISTIC | 需追踪 entity 字段赋值链 |
| 判断 find 结果是否到达 Sink | HEURISTIC | 需追踪返回值的使用链 |
| 判断 th:utext vs th:text | DETERMINISTIC | 模板语法明确 |
| 跨请求关联（写入端点↔读取端点） | SUBJECTIVE | 需要理解业务逻辑才能关联 |
