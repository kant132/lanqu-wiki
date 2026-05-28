# XXE审计分支

## 触发条件

- 标签: `XXE_PARSE`
- 优先级: 1（高危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| XXE1 | XML解析器是否禁用外部实体（`FEATURE_SECURE_PROCESSING`）？ |
| XXE2 | 是否禁用DTD处理（`disallow-doctype-decl`）？ |
| XXE3 | 是否禁用外部参数实体？ |
| XXE4 | XSLT是否禁用外部函数和实体？ |
| XXE5 | XML输入是否来自不可信来源？ |

## 危险Sink清单

```java
// DOM
DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(input)
// 未设置: setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)

// SAX
SAXParserFactory.newInstance().newSAXParser().parse(input, handler)
XMLReader.parse(input)

// StAX
XMLInputFactory.newInstance().createXMLStreamReader(input)
// 未设置: setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false)

// Transform
TransformerFactory.newInstance().newTransformer(source)

// 其他
Unmarshaller.unmarshal(input)  // JAXB
SchemaFactory.newSchema(source)
```

## 安全配置模板

```java
// 推荐配置
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
dbf.setXIncludeAware(false);
dbf.setExpandEntityReferences(false);
```

## 审计流程

```
1. 定位XML解析Sink点
2. 检查解析器工厂的安全配置
3. 反向追踪XML数据来源
4. 使用LSP确认数据来源可控性
5. 生成漏洞报告或标记为安全
```

## 输出格式

```json
{
  "branch": "xxe",
  "findings": [
    {
      "type": "XXE",
      "severity": "HIGH",
      "sink": "XmlService.java:32",
      "source": "ApiController.java:18 @RequestBody",
      "evidence": "DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(input)",
      "sanitization": "未禁用外部实体，未禁用DTD",
      "poc": "<?xml version=\"1.0\"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM \"file:///etc/passwd\">]><data>&xxe;</data>"
    }
  ]
}
```
