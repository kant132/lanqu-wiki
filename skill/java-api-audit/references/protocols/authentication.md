# 认证流程安全审计清单

## PWD-RESET: 密码重置流程

### 识别特征

```
端点/方法: resetPassword, forgotPassword, sendResetLink, changePassword, passwordReset
参数: resetToken, resetLink, email, newPassword, confirmPassword
模板: password-reset, forgot-password, reset-password
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| PR-01 | 重置令牌生成 | 重置令牌必须使用密码学安全的随机数生成器（SecureRandom），长度 ≥ 128 bit | 检查令牌生成代码；是否使用 UUID.randomUUID() 或 SecureRandom；禁止使用 java.util.Random | CRITICAL |
| PR-02 | 重置令牌过期 | 重置令牌必须有合理的过期时间（通常 15-60 分钟） | 检查令牌是否关联过期时间；检查验证时是否校验过期 | HIGH |
| PR-03 | 重置令牌一次性使用 | 重置令牌使用后必须立即失效，不得重复使用 | 检查密码修改后是否删除/标记令牌已使用；检查并发场景 | HIGH |
| PR-04 | 重置令牌与用户绑定 | 重置令牌必须与申请时的用户绑定，防止令牌被用于其他账户 | 检查令牌验证时是否校验用户身份 | CRITICAL |
| PR-05 | 邮箱枚举防护 | 密码重置接口不得通过响应差异泄露邮箱是否已注册 | 检查"邮箱不存在"和"邮箱存在"的响应是否一致（相同消息/相同延迟） | MEDIUM |
| PR-06 | 重置链接 Host 头注入 | 重置链接的域名不得从 HTTP Host header 获取，防止投毒 | 检查重置链接的 URL 构建逻辑；是否使用配置的固定域名而非 request.getServerName() | CRITICAL |
| PR-07 | 新密码强度校验 | 新密码必须满足强度要求（长度、复杂度、不在常见密码列表中） | 检查密码校验逻辑；是否使用 zxcvbn 等库 | MEDIUM |
| PR-08 | 旧密码验证 | 修改密码（非重置）时应验证旧密码 | 检查修改密码接口是否要求输入旧密码 | HIGH |
| PR-09 | 通知机制 | 密码重置成功后应通知用户（邮件/短信），告知账户发生了变更 | 检查是否有通知逻辑 | LOW |
| PR-10 | 暴力破解防护 | 密码重置接口应有频率限制，防止批量枚举 | 检查是否有 RateLimiter/Throttle；检查失败次数限制 | HIGH |

---

## EMAIL-VERIFY: 邮箱验证流程

### 识别特征

```
端点/方法: verifyEmail, confirmEmail, activation, verificationToken
```

> **注意**: 原始文件中 EMAIL-VERIFY 仅在协议索引中列出（7 项检查项），但未包含详细审计清单。需要补充完整内容。

---

## MFA: 多因素认证

### 识别特征

```
关键词: twoFactor, mfa, otp, totp, authenticator, smsCode, verificationCode, google-authenticator
库: commons-codec (TOTP), google-authenticator, spring-security-otp
```

### 安全审计清单

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| MFA-01 | OTP 密钥存储 | TOTP 密钥（shared secret）必须加密存储，不得明文存储 | 检查密钥存储方式；是否使用加密字段/加密数据库 | CRITICAL |
| MFA-02 | OTP 验证窗口 | TOTP 验证应允许 ±1 步的时间窗口（通常 30 秒 × 3 = 90 秒） | 检查验证逻辑的时间窗口配置 | MEDIUM |
| MFA-03 | OTP 暴力破解防护 | OTP 验证接口必须有频率限制（如 5 次失败后锁定） | 检查是否有失败次数限制；检查是否有 IP/用户级别的锁定 | CRITICAL |
| MFA-04 | 备份码机制 | 应提供一次性备份码，防止用户丢失认证器后无法登录 | 检查是否有备份码生成和验证逻辑 | MEDIUM |
| MFA-05 | MFA 绕过风险 | 密码重置/账户恢复流程不得绕过 MFA | 检查密码重置后是否要求重新设置 MFA；检查是否有"记住设备"功能的安全实现 | CRITICAL |
| MFA-06 | SMS OTP 风险 | SMS OTP 存在 SIM 交换攻击风险，高安全场景应使用 TOTP 或硬件密钥 | 检查是否仅依赖 SMS OTP；是否有替代方案 | MEDIUM |
| MFA-07 | 会话与 MFA 绑定 | MFA 验证后的会话应标记为"已 MFA 验证"，敏感操作需检查此标记 | 检查 Session 中是否有 MFA 验证标记；检查敏感操作是否检查此标记 | HIGH |
| MFA-08 | 设备信任安全 | "记住此设备"功能应使用安全的设备指纹，不得仅依赖 Cookie | 检查设备信任的实现方式；Cookie 是否 HttpOnly/Secure；是否有过期时间 | MEDIUM |
