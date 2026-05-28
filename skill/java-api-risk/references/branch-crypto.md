# 密码学审计分支

## 触发条件

- 标签: `CRYPTO_WEAK`, `HARDCODED_KEY`
- 优先级: 3（中危）

## 审计检查点

| 检查项 | 说明 |
|--------|------|
| CR1 | 是否使用弱加密算法（DES, 3DES, RC4）？ |
| CR2 | 是否使用弱哈希算法（MD5, SHA1）用于安全场景？ |
| CR3 | AES是否使用安全模式（CBC/GCM而非ECB）？ |
| CR4 | IV是否随机生成而非硬编码？ |
| CR5 | 密钥是否硬编码或过短（RSA < 2048, AES < 128）？ |
| CR6 | 是否使用`SecureRandom`而非`Random`？ |
| CR7 | 密码存储是否使用安全哈希（BCrypt, Argon2, PBKDF2）？ |
| CR8 | TLS配置是否禁用弱密码套件？ |

## 危险模式

```java
// 弱算法
Cipher.getInstance("DES")
Cipher.getInstance("DESede")
Cipher.getInstance("RC4")
Cipher.getInstance("AES/ECB/...")  // ECB模式

// 弱哈希
MessageDigest.getInstance("MD5")
MessageDigest.getInstance("SHA-1")

// 硬编码密钥
byte[] key = "mySecretKey12345".getBytes();
SecretKeySpec keySpec = new SecretKeySpec(key, "AES");

// 不安全随机数
new Random().nextInt()  // 用于安全场景
Math.random()           // 用于安全场景

// 不安全密码存储
password.hashCode()
DigestUtils.md5Hex(password)
```

## 安全替代方案

| 场景 | 不安全 | 安全替代 |
|------|--------|----------|
| 对称加密 | DES, AES/ECB | AES/GCM/NoPadding |
| 哈希 | MD5, SHA1 | SHA-256, SHA-3 |
| 密码存储 | MD5, SHA1 | BCrypt, Argon2, PBKDF2 |
| 随机数 | Random | SecureRandom |
| RSA密钥 | 1024位 | 2048位以上 |

## 审计流程

```
1. 扫描加密相关API调用
2. 识别使用的算法和模式
3. 检查密钥来源（硬编码/配置/密钥库）
4. 检查IV生成方式
5. 检查随机数生成器类型
6. 评估算法强度
7. 生成漏洞报告或标记为安全
```

## 输出格式

```json
{
  "branch": "crypto",
  "findings": [
    {
      "type": "弱加密 + 硬编码密钥",
      "severity": "HIGH",
      "sink": "CryptoUtil.java:22",
      "source": "硬编码",
      "evidence": "Cipher.getInstance(\"AES/ECB/PKCS5Padding\") + 硬编码密钥",
      "sanitization": "无",
      "recommendation": "使用AES/GCM + KeyStore管理密钥"
    }
  ]
}
```
