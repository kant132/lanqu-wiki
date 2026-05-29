# 业务逻辑漏洞审计

## 1. 审计范围

业务逻辑漏洞不依赖传统的 Source→Sink 污点传播，而是通过**业务流程分析**发现。以下类型需要专项审计：

## 2. 漏洞类型与审计方法

### 2.1 竞态条件（Race Condition）

```
审计目标: 并发请求导致数据不一致

扫描模式:
  - 余额/库存扣减: grep "balance", "stock", "quantity", "count" 的 UPDATE 操作
  - 检查是否使用 SELECT ... FOR UPDATE 或乐观锁（@Version）
  - 检查是否有分布式锁（Redis SETNX, Redisson）

判定规则:
  DETERMINISTIC: UPDATE ... SET balance = balance - #{amount} 无锁 → 竞态条件确认
  HEURISTIC:    使用 @Transactional 但无 @Version → 需确认隔离级别
  DETERMINISTIC: 使用 @Version 或 SELECT FOR UPDATE → 安全

输出:
  | 端点 | 操作 | 锁机制 | 风险 | 严重度 |
  |------|------|--------|------|--------|
  | POST /transfer | 余额扣减 | 无 | 双重提交可导致余额为负 | HIGH |
```

### 2.2 状态机违规（State Machine Violation）

```
审计目标: 跳过业务流程步骤

扫描模式:
  - 状态字段: grep "status", "state", "phase", "step" 的 Entity 字段
  - 状态转换: 识别所有修改状态的方法
  - 检查是否验证了前置状态（如: 只有 status=PAID 才能 SHIPPED）

判定规则:
  DETERMINISTIC: order.setStatus("SHIPPED") 无前置状态检查 → 状态机违规确认
  HEURISTIC:    if (order.getStatus() == "PAID") → 需确认是否所有路径都检查
  DETERMINISTIC: 使用 Spring StateMachine 或枚举状态转换表 → 安全

输出:
  | 端点 | 当前状态检查 | 目标状态 | 风险 | 严重度 |
  |------|-------------|----------|------|--------|
  | POST /orders/{id}/ship | 无 | SHIPPED | 可跳过支付直接发货 | CRITICAL |
```

### 2.3 价格/金额篡改

```
审计目标: 客户端可控制价格计算

扫描模式:
  - 价格参数: grep "price", "amount", "total", "cost", "discount" 的 @RequestParam
  - 检查价格是否从服务端数据库获取，还是接受客户端传入
  - 检查折扣/优惠券是否在服务端验证

判定规则:
  DETERMINISTIC: @RequestParam BigDecimal price → 直接用于计算 → 价格篡改确认
  HEURISTIC:    @RequestParam String couponCode → 需确认折扣验证逻辑
  DETERMINISTIC: price = productRepository.findById(id).getPrice() → 安全（服务端获取）

输出:
  | 端点 | 价格来源 | 折扣验证 | 风险 | 严重度 |
  |------|----------|----------|------|--------|
  | POST /checkout | 客户端传入 price | 无 | 可设置 price=0 免费购买 | CRITICAL |
```

### 2.4 工作流绕过（Workflow Bypass）

```
审计目标: 跳过审批/验证步骤

扫描模式:
  - 审批链: grep "approve", "review", "audit", "confirm" 的端点
  - 检查最终操作是否验证了审批状态
  - 检查是否可直接调用最终操作端点（绕过审批端点）

判定规则:
  DETERMINISTIC: POST /expense/{id}/pay 不检查 approval_status → 工作流绕过确认
  HEURISTIC:    if (expense.isApproved()) → 需确认 isApproved 逻辑是否可被绕过

输出:
  | 最终操作端点 | 审批检查 | 风险 | 严重度 |
  |-------------|----------|------|--------|
  | POST /expense/{id}/pay | 无 | 可跳过审批直接付款 | CRITICAL |
```

### 2.5 批量枚举（Enumeration）

```
审计目标: 可遍历敏感资源 ID

扫描模式:
  - ID 参数: @PathVariable Long id / @RequestParam Long id
  - 检查 ID 是否为连续数字（自增主键）
  - 检查是否有频率限制
  - 检查是否验证了当前用户对资源的所属权

判定规则:
  DETERMINISTIC: GET /orders/{id} 无所属权检查 + 自增 ID → 枚举确认
  HEURISTIC:    GET /orders/{uuid} → UUID 不可预测，风险降低
  DETERMINISTIC: 有频率限制 + 所属权检查 → 安全

输出:
  | 端点 | ID 类型 | 所属权检查 | 频率限制 | 风险 | 严重度 |
  |------|---------|-----------|----------|------|--------|
  | GET /orders/{id} | 自增 Long | 无 | 无 | 可遍历所有订单 | HIGH |
```

### 2.6 优惠券/折扣滥用

```
审计目标: 优惠券可被重复使用或叠加

扫描模式:
  - 优惠券逻辑: grep "coupon", "discount", "voucher", "promo" 的代码
  - 检查优惠券是否标记为已使用
  - 检查是否限制每用户/每订单使用次数
  - 检查是否可叠加多个优惠券

判定规则:
  DETERMINISTIC: coupon.apply() 无使用次数检查 → 重复使用确认
  HEURISTIC:    if (!coupon.isUsed()) → 需确认并发场景下是否安全

输出:
  | 端点 | 优惠券验证 | 使用限制 | 风险 | 严重度 |
  |------|-----------|----------|------|--------|
  | POST /checkout | 仅验证有效性 | 无次数限制 | 优惠券可无限重复使用 | MEDIUM |
```

## 3. 审计流程

```
1. 从 API 清单中筛选业务操作类端点:
   - 包含 create/update/delete/pay/transfer/approve/checkout 等关键词
   - 排除纯查询/健康检查/静态资源端点

2. 对筛选出的端点，按上述 6 种类型逐一检查

3. 每种类型输出:
   - 受影响的端点列表
   - 具体的代码证据（文件:行号）
   - 置信度（CONFIRMED/LIKELY/POSSIBLE）
   - PoC 思路

4. 业务逻辑漏洞不纳入三维评分体系，单独列为"业务逻辑风险"章节
```

## 4. 确定性标注

| 漏洞类型 | 扫描确定性 | 判定确定性 | 说明 |
|----------|-----------|-----------|------|
| 竞态条件 | DETERMINISTIC (grep) | HEURISTIC | 能确定找到 UPDATE 操作，但锁机制分析需要理解上下文 |
| 状态机违规 | DETERMINISTIC (grep) | HEURISTIC | 能确定找到状态修改，但前置状态检查分析需要理解业务流 |
| 价格篡改 | DETERMINISTIC (grep) | DETERMINISTIC | @RequestParam price 直接用于计算 = 确定性漏洞 |
| 工作流绕过 | HEURISTIC (grep) | SUBJECTIVE | 需要理解业务流程才能判断哪些步骤是必须的 |
| 批量枚举 | DETERMINISTIC (grep) | HEURISTIC | 能确定找到 ID 参数，但所属权检查分析需要理解权限模型 |
| 优惠券滥用 | HEURISTIC (grep) | SUBJECTIVE | 需要理解优惠业务规则 |
