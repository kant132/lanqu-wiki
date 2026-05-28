# Phase 5 Audit-Context.json 协议规范

## 隔离交付物说明

子 Agent 必须生成纯文本 JSON，主 Agent 仅解析该 JSON 块。

## JSON 结构

```json
{
  "audit_meta": {
    "engine_mode": "Param-Modeler-Sandbox",
    "timestamp": "2026-05-27T11:20:00Z",
    "total_sources_extracted": 4,
    "frameworks_detected": ["Spring MVC", "JAX-RS", "Native Servlet", "Dubbo RPC"]
  },
  "api_route_assets": [
    {
      "asset_id": "ROUTE-001",
      "engine": "Spring MVC",
      "path": "GET /api/v1/backup/download/{fileId}",
      "mean": "接口业务意义",
      "next_step": "基于业务意义，重点分析哪个参数可能对应的安全风险",
      "method": "GET",
      "controller_class": "com.secure.gateway.controller.BackupController",
      "method_signature": "downloadBackup(String fileId)",
      "parameters": [
        {
          "name": "fileId",
          "binding": "@PathVariable",
          "type": "java.lang.String"
        }
      ],
      "risk_modeling": {
        "factors": {
          "authentication": 5,
          "global_filter": 3,
          "validation": 5
        },
        "score": 75,
        "priority": "CRITICAL",
        "validation_detail": "Zero_Validation",
        "trigger_deep_trace": true
      }
    }
  ],
  "execution_queue": {
    "will_positive_trace_ids": ["ROUTE-001"],
    "skipped_low_risk_ids": []
  }
}
```

## 字段说明

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| `audit_meta.engine_mode` | string | 执行模式标识 |
| `audit_meta.timestamp` | string | ISO 8601 时间戳 |
| `audit_meta.total_sources_extracted` | number | 提取的入口点总数 |
| `audit_meta.frameworks_detected` | array | 检测到的框架列表 |
| `api_route_assets[].asset_id` | string | 路由资产唯一标识 |
| `api_route_assets[].engine` | string | 路由引擎类型 |
| `api_route_assets[].path` | string | 完整路由路径 |
| `api_route_assets[].mean` | string | 接口业务意义描述 |
| `api_route_assets[].next_step` | string | 下一步分析建议 |
| `api_route_assets[].risk_modeling.score` | number | 风险评分 |
| `api_route_assets[].risk_modeling.priority` | string | 风险等级 |
| `execution_queue.will_positive_trace_ids` | array | 需要正向追踪的路由ID列表 |
| `execution_queue.skipped_low_risk_ids` | array | 因低风险被跳过的路由ID列表 |
