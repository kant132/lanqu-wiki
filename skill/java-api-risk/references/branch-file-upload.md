# 文件上传审计分支

## 触发条件

- 标签: `FILE_UPLOAD`
- 优先级: 2（中高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| FU1 | 是否校验文件MIME类型（白名单）？ |
| FU2 | 是否校验文件扩展名（白名单）？ |
| FU3 | 是否校验文件内容（Magic Bytes）？ |
| FU4 | 文件名是否净化（去除`../`、空字节）？ |
| FU5 | 上传目录是否禁止执行（`web.xml`配置）？ |
| FU6 | 是否限制文件大小？ |
| FU7 | 是否使用随机文件名而非原始文件名？ |
| FU8 | 上传目录是否在Web根目录之外？ |

## 危险Sink清单

```java
// Spring MVC
MultipartFile.transferTo(new File(uploadPath + fileName))
MultipartFile.getInputStream()

// Commons FileUpload
FileItem.write(new File(uploadPath + fileName))

// Servlet 3.0+
Part.write(uploadPath + fileName)
```

## 绕过技术清单

| 绕过方式 | 说明 |
|----------|------|
| 双扩展名 | `shell.php.jpg` / `shell.jpg.php` |
| 空字节注入 | `shell.php%00.jpg` |
| MIME伪造 | `Content-Type: image/jpeg` 但实际为JSP |
| 大小写绕过 | `shell.PhP` / `shell.Jsp` |
| 特殊扩展名 | `.phtml`, `.php5`, `.shtml` |
| .htaccess上传 | 上传 `.htaccess` 修改目录解析规则 |
| 条件竞争 | 上传临时文件 → 在删除前访问执行 |

## 审计流程

```
1. 定位文件上传处理点
2. 检查文件名处理逻辑
3. 检查MIME/扩展名校验
4. 检查文件内容校验
5. 检查上传目录配置
6. 使用LSP追踪文件名到存储路径
7. 生成漏洞报告或标记为安全
```

## 输出格式

```json
{
  "branch": "file-upload",
  "findings": [
    {
      "type": "任意文件上传",
      "severity": "CRITICAL",
      "sink": "UploadService.java:45",
      "source": "UploadController.java:22 @RequestParam MultipartFile",
      "evidence": "file.transferTo(new File(uploadDir + file.getOriginalFilename()))",
      "sanitization": "仅校验Content-Type头，未校验文件内容",
      "poc": "上传shell.jsp，Content-Type伪造为image/jpeg"
    }
  ]
}
```
