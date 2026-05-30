# 支付/交易流程安全审计清单

## PAYMENT: 支付/交易流程

### 识别特征

```
关键词: payment, charge, transfer, transaction, order, checkout, amount, currency, refund
端点: /pay, /checkout, /transfer, /order/create, /refund
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| PAY-01 | 金额服务端计算 | 支付金额必须由服务端计算，不得接受客户端传入的金额 | 检查金额参数来源；是否从数据库/服务端计算；是否接受客户端 @RequestParam amount | CRITICAL |
| PAY-02 | 幂等性 | 支付接口必须实现幂等性，防止重复扣款 | 检查是否有幂等键（idempotency key）；检查是否有去重逻辑 | CRITICAL |
| PAY-03 | 竞态条件防护 | 余额扣减必须使用数据库锁（SELECT FOR UPDATE 或乐观锁） | 检查 UPDATE 语句是否有 WHERE balance >= amount；是否使用 @Version | CRITICAL |
| PAY-04 | 负数金额 | 金额参数必须校验为正数，防止负数金额导致余额增加 | 检查金额参数的校验逻辑；是否有 @Min(0) 或手动校验 | CRITICAL |
| PAY-05 | 货币精度 | 金额计算必须使用 BigDecimal，禁止使用 float/double | 检查金额字段类型；搜索 float/double 用于金额的场景 | HIGH |
| PAY-06 | 交易签名 | 支付请求应有防篡改签名（HMAC/RSA），防止参数被修改 | 检查是否有签名生成和验证逻辑；签名是否覆盖所有关键参数 | HIGH |
| PAY-07 | 回调验证 | 支付网关回调必须验证签名/IP 白名单，防止伪造回调 | 检查回调接口的验证逻辑；是否验证签名；是否限制来源 IP | CRITICAL |
| PAY-08 | 状态机完整性 | 订单状态转换必须遵循预定义的状态机，禁止非法跳转 | 检查状态转换逻辑；是否有前置状态验证 | HIGH |
| PAY-09 | 审计日志 | 所有支付操作必须有完整的审计日志（操作人、时间、金额、前后状态） | 检查是否有日志记录；日志内容是否完整 | HIGH |
| PAY-10 | 退款控制 | 退款金额不得超过原始交易金额；退款应有审批流程 | 检查退款金额校验；检查是否有审批机制 | HIGH |
