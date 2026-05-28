# 路径穿越审计分支

## 触发条件

- 标签: `FILE_PATH`, `FILE_INPUT`
- 优先级: 2（中高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| PT1 | 文件路径是否经过规范化处理（`Path.normalize()`）？ |
| PT2 | 是否检查路径是否在允许的基目录内（`startsWith(basePath)`）？ |
| PT3 | 是否过滤 `../`、`..\\`、`..;/` 等穿越序列？ |
| PT4 | 是否处理URL编码绕过（`%2e%2e%2f`、`%252e%252e%252f`）？ |
| PT5 | 是否处理空字节注入（`%00`）？ |
| PT6 | 文件名是否使用白名单或安全的随机生成？ |
| PT7 | 是否限制文件扩展名？ |

## 危险Sink清单

```java
// 文件读取
new File(path)
new FileInputStream(path)
Files.readAllBytes(Paths.get(path))
Files.newInputStream(Paths.get(path))

// 文件写入
new FileOutputStream(path)
Files.write(Paths.get(path), data)
Files.copy(source, Paths.get(path))

// 资源加载
ClassLoader.getResource(path)
ServletContext.getResource(path)
ServletContext.getRealPath(path)
```

## 审计流程

```
1. 定位文件操作Sink点
2. 反向追踪路径参数来源
3. 检查是否存在路径规范化
4. 检查是否存在基目录校验
5. 检查是否过滤穿越字符
6. 使用LSP确认参数可控性
7. 生成漏洞报告或标记为安全
```

## 回溯请求触发条件

- 路径参数来自Service层方法 → 请求追踪调用链
- 路径来自数据库字段 → 检查写入时是否净化

## 输出格式

```json
{
  "branch": "path-traversal",
  "findings": [
    {
      "type": "路径穿越",
      "severity": "HIGH",
      "sink": "FileService.java:42",
      "source": "FileController.java:18 @PathVariable",
      "evidence": "new File(basePath + \"/\" + fileName)",
      "sanitization": "无normalize，无startsWith校验",
      "poc": "GET /api/files/..%2F..%2Fetc%2Fpasswd"
    }
  ]
}
```
