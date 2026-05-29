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

Config_Analysis:
  Files:
    - Path: "STR"
      Profiles: ["STR"]
  Security_Config:
    - Key: "STR"
      Value: "STR"
      File: "STR"
      Line: INT
      Risk: "HIGH|MEDIUM|LOW"
      Note: "STR"
  Datasource_Config:
    - Key: "STR"
      Value: "STR"
      File: "STR"
      Line: INT
      Risk: "HIGH|MEDIUM|LOW"
  Upload_Config:
    - Key: "STR"
      Value: "STR"
      File: "STR"
      Line: INT
      Risk: "HIGH|MEDIUM|LOW"
  Actuator_Config:
    - Key: "STR"
      Value: "STR"
      File: "STR"
      Line: INT
      Risk: "HIGH|MEDIUM|LOW"
  Cors_Config:
    - Key: "STR"
      Value: "STR"
      File: "STR"
      Line: INT
      Risk: "HIGH|MEDIUM|LOW"
  Serialization_Config:
    - Key: "STR"
      Value: "STR"
      File: "STR"
      Line: INT
      Risk: "HIGH|MEDIUM|LOW"
  Custom_Business_Config:
    - Key: "STR"
      Value: "STR"
      File: "STR"
      Line: INT
      Risk: "HIGH|MEDIUM|LOW"
      Note: "STR"
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
| `Config_Analysis` | Object | 配置文件深度分析结果 |
| `Config_Analysis.Files` | Array[Object] | 扫描到的配置文件清单 |
| `Config_Analysis.Security_Config` | Array[Object] | 认证授权相关配置 |
| `Config_Analysis.Datasource_Config` | Array[Object] | 数据源相关配置 |
| `Config_Analysis.Upload_Config` | Array[Object] | 文件上传相关配置 |
| `Config_Analysis.Actuator_Config` | Array[Object] | Actuator 端点配置 |
| `Config_Analysis.Cors_Config` | Array[Object] | CORS 跨域配置 |
| `Config_Analysis.Serialization_Config` | Array[Object] | 序列化相关配置 |
| `Config_Analysis.Custom_Business_Config` | Array[Object] | 自定义业务配置 |

## 示例

```markdown
[INIT_STAGE]
_generated_at: "2026-05-28T10:30:00Z"
_assertions_passed: ["C1", "C2", "C3", "C4", "C5", "C6"]

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

Config_Analysis:
  Files:
    - Path: "src/main/resources/application.yml"
      Profiles: ["default", "dev", "prod"]
    - Path: "src/main/resources/application-dev.yml"
      Profiles: ["dev"]
  Security_Config:
    - Key: "security.jwt.secret"
      Value: "[REDACTED]"
      File: "application.yml"
      Line: 45
      Risk: "HIGH"
      Note: "JWT 密钥配置在配置文件中，需确认是否硬编码"
    - Key: "security.whitelist.paths"
      Value: "/api/public/**,/health,/actuator/**"
      File: "application.yml"
      Line: 48
      Risk: "MEDIUM"
      Note: "白名单路径包含 actuator，需确认是否暴露敏感端点"
  Datasource_Config:
    - Key: "spring.datasource.url"
      Value: "jdbc:mysql://localhost:3306/mydb"
      File: "application-dev.yml"
      Line: 12
      Risk: "LOW"
  Actuator_Config:
    - Key: "management.endpoints.web.exposure.include"
      Value: "health,info,env,beans,configprops"
      File: "application.yml"
      Line: 62
      Risk: "HIGH"
      Note: "暴露了 env 和 configprops 端点，可能泄露敏感配置"
  Cors_Config:
    - Key: "cors.allowed-origins"
      Value: "*"
      File: "application.yml"
      Line: 70
      Risk: "HIGH"
      Note: "CORS 允许所有来源，存在跨域攻击风险"
  Custom_Business_Config:
    - Key: "csb.gateway.timeout"
      Value: "30000"
      File: "application.yml"
      Line: 85
      Risk: "LOW"
      Note: "云网关超时配置"
```