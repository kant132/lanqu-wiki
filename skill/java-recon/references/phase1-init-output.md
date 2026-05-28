# Phase 1 输出模板

## INIT_STAGE

```markdown
[INIT_STAGE]
_generated_at: "TIMESTAMP"
_assertions_passed: ["C1", "C2", "C3", "C4", "C5"]

Project_Type: "Maven / Gradle"
JDK_Version: "STRING"

Framework_Sensing:
  detected_engines: ["Engine_Name (Version)"]
  security_framework: "Framework_Name (Version)"

Asset_Inventory:
  Filters:
    - ID: "F001"
      Name: "STR"
      Source: "STR"
      ClassPath: "STR"
      UrlPatterns: []
  Interceptors:
    - ID: "I001"
      Name: "STR"
      Source: "STR"
      ClassPath: "STR"
      PathPatterns: []
      ExcludePatterns: []

Total_Count:
  Filters: INT
  Interceptors: INT
  Total_Assets: INT
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `_generated_at` | TIMESTAMP | 审计时间戳，ISO 8601格式 |
| `_assertions_passed` | Array[String] | 通过的门禁断言代码列表 |
| `Project_Type` | String | 项目类型：Maven 或 Gradle |
| `JDK_Version` | String | JDK版本号 |
| `detected_engines` | Array[String] | 检测到的路由引擎及版本 |
| `security_framework` | String | 检测到的安全框架及版本 |
| `Filters` | Array[Object] | Filter资产清单 |
| `Interceptors` | Array[Object] | Interceptor资产清单 |
| `Total_Assets` | INT | 资产总数 |

## 示例

```markdown
[INIT_STAGE]
_generated_at: "2026-05-28T10:30:00Z"
_assertions_passed: ["C1", "C2", "C3", "C4", "C5"]

Project_Type: "Maven"
JDK_Version: "17"

Framework_Sensing:
  detected_engines: ["Spring WebMVC (6.0.12)", "Spring Security (6.0.9)"]
  security_framework: "Spring Security (6.0.9)"

Asset_Inventory:
  Filters:
    - ID: "F001"
      Name: "CorsFilter"
      Source: "web.xml"
      ClassPath: "org.apache.catalina.filters.CorsFilter"
      UrlPatterns: ["/*"]
  Interceptors:
    - ID: "I001"
      Name: "AuthInterceptor"
      Source: "Spring MVC"
      ClassPath: "com.example.interceptor.AuthInterceptor"
      PathPatterns: ["/api/**"]
      ExcludePatterns: ["/api/public/**", "/health"]

Total_Count:
  Filters: 1
  Interceptors: 1
  Total_Assets: 2
```