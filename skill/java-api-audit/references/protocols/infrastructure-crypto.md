# 密码算法与密钥管理安全审计清单

## CRYPTO-ALG: 密码算法安全

**识别特征:** `MessageDigest`, `Cipher`, `SecretKeyFactory`, `KeyGenerator`, `Signature`, BouncyCastle

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CALG-01 | 哈希算法选择 | 禁止 MD5/SHA1 用于安全场景（密码存储、签名），应使用 SHA-256+ | 搜索 `MessageDigest.getInstance("MD5"/"SHA-1")` | HIGH |
| CALG-02 | 对称加密算法 | 禁止 DES/3DES/RC4，应使用 AES-256-GCM | 搜索 `Cipher.getInstance` 中的算法名 | CRITICAL |
| CALG-03 | 非对称加密算法 | RSA 密钥 ≥ 2048 bit，推荐 ECC (P-256+) | 搜索 `KeyPairGenerator.initialize()` 的 keySize | HIGH |
| CALG-04 | 加密模式 | 禁止 ECB 模式，应使用 GCM/CBC+HMAC | 搜索 `Cipher.getInstance` 中的模式 | CRITICAL |
| CALG-05 | 填充方式 | 禁止 NoPadding/PKCS5Padding(配合ECB)，应使用 OAEP(RSA)/GCM(AES) | 搜索 `Cipher.getInstance` 中的 padding | HIGH |
| CALG-06 | IV 管理 | IV 必须随机生成且不可重复使用（CBC/GCM），不得硬编码 | 搜索 `IvParameterSpec` 的构造方式 | CRITICAL |
| CALG-07 | 随机数生成 | 安全场景必须使用 `SecureRandom`，禁止 `java.util.Random` | 搜索 `new Random()` 在安全上下文中的使用 | CRITICAL |
| CALG-08 | 密码存储 | 密码必须使用 bcrypt/scrypt/Argon2 哈希，禁止 MD5/SHA+salt | 搜索 `PasswordEncoder` 实现；搜索 `MessageDigest` 用于密码 | CRITICAL |
| CALG-09 | 签名算法 | 禁止 MD5withRSA/SHA1withRSA，应使用 SHA256withRSA 或 EdDSA | 搜索 `Signature.getInstance` 中的算法 | HIGH |
| CALG-10 | 密钥派生 | 密钥派生应使用 HKDF/PBKDF2，禁止简单哈希 | 搜索 `SecretKeyFactory.getInstance` | HIGH |

---

## CRYPTO-KEY: 密钥管理

**识别特征:** `@Value("${*.secret}")`, `@Value("${*.key}")`, `KeyStore`, `SecretKey`, `PrivateKey`

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CKEY-01 | 密钥硬编码 | 密钥不得硬编码在源代码中 | 搜索 password/secret/key/apiKey 的字符串字面量赋值 | CRITICAL |
| CKEY-02 | 密钥存储 | 密钥应存储在 KMS/HSM/Vault 中，至少使用环境变量 | 检查密钥来源（`@Value`、配置文件、环境变量） | HIGH |
| CKEY-03 | 密钥轮换 | 应支持密钥轮换机制，不得永久使用同一密钥 | 检查是否有密钥轮换逻辑 | MEDIUM |
| CKEY-04 | 密钥长度 | 对称密钥 ≥ 128 bit (推荐 256)，非对称 ≥ 2048 bit | 检查密钥生成时的 keySize 参数 | HIGH |
| CKEY-05 | 密钥泄露 | 密钥不得出现在日志、异常消息、错误响应中 | 搜索日志/异常中是否引用密钥变量 | HIGH |
| CKEY-06 | KeyStore 保护 | KeyStore 密码不得硬编码，KeyStore 文件应有访问控制 | 搜索 `KeyStore.load()` 的密码来源 | HIGH |
| CKEY-07 | 内存中密钥 | 密钥使用后应尽快从内存清除（使用 `char[]` 而非 `String`） | 检查密钥是否存储在 `String` 中（不可清除） | MEDIUM |
| CKEY-08 | 传输中密钥 | 密钥传输必须加密（TLS），不得通过明文通道传输 | 检查密钥获取的 URL 是否 HTTPS | HIGH |

---

## CRYPTO-MODE: 加密实现模式

**识别特征:** `Cipher`, `Mac`, `MessageDigest.isEqual`, `X509TrustManager`, BouncyCastle 版本

| 检查项 | 审计内容 | 安全规范 | 验证方法 | 严重度 |
|--------|----------|----------|----------|--------|
| CMODE-01 | 认证加密 | 应使用 AEAD（GCM/CCM），或 Encrypt-then-MAC | 检查是否使用 GCM 或独立的 MAC | HIGH |
| CMODE-02 | 时间侧信道 | 密码比较/签名验证应使用常量时间比较 | 搜索 `Arrays.equals` / `MessageDigest.isEqual` vs `==` | HIGH |
| CMODE-03 | 错误处理 | 解密失败不得泄露具体原因（padding error vs auth error） | 检查异常处理是否区分错误类型 | MEDIUM |
| CMODE-04 | 加密库版本 | 使用已知安全的加密库版本，避免已知 CVE | 检查 BouncyCastle/jose4j 等版本 | HIGH |
| CMODE-05 | 自定义加密 | 禁止自行实现加密算法，必须使用标准库 | 搜索自定义 Cipher/Hash 实现 | CRITICAL |
| CMODE-06 | 证书验证 | HTTPS 客户端必须验证服务器证书，禁止信任所有证书 | 搜索 `TrustAll`/`X509TrustManager` 空实现 | CRITICAL |
