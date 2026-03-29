# 快速开始 - ClawUI 应用包开发

## ⚡ 概述

现在项目使用正确的 Alpine Linux `.apk` 包格式，而不是 `.tar.gz`。

## 新增应用

已创建以下应用的 APK 包：

### 1. KMS Server (kms-server)
- **功能**: Windows/Office KMS 激活服务器
- **端口**: 1688
- **文件位置**: `clawui/apps/kms/`

### 2. NPS Client (nps-client)
- **功能**: 内网穿透反向代理
- **特点**: 支持 HTTP/HTTPS、TCP/UDP 隧道、SOCKS5
- **文件位置**: `clawui/apps/nps/`

### 3. Aria2 Download (aria2)
- **功能**: 轻量级多协议下载管理器
- **协议**: HTTP/HTTPS/FTP/BitTorrent/Metalink
- **RPC 端口**: 6800
- **文件位置**: `clawui/apps/aria2/`

## 🚀 快速构建

### 构建所有 APK 包

```bash
cd /home/node/.openclaw/workspace/ax6600-alpine-clean

# 方法 1: 简单构建（无需 abuild）
./scripts/build-apk-simple.sh all

# 方法 2: 完整构建（需要 Alpine 构建工具）
apk add abuild devtools
./scripts/build-apk-packages.sh all
```

### 构建单个应用

```bash
# 构建 KMS 服务器
./scripts/build-apk-simple.sh build kms

# 构建 NPS 客户端
./scripts/build-apk-simple.sh build nps

# 构建 Aria2
./scripts/build-apk-simple.sh build aria2
```

### 完整固件构建（包含所有 APK）

```bash
# 设置环境变量
export BUILD_APKS=1
export INSTALL_APKS=1

# 构建完整固件
./build.sh
```

## 📦 APK 包结构

每个 APK 包包含：

```
apps/<appname>/
├── APKBUILD          # Alpine 包定义文件
├── manifest.json     # ClawUI 应用清单
├── www/              # Web 界面
│   └── index.html
├── api/
│   └── handler.sh    # API 接口
├── i18n/
│   └── translations.json
├── <appname>.init    # OpenRC 启动脚本
└── <appname>.conf    # 配置文件
```

## 🔧 安装到路由器

### 方法 1: 集成到固件

构建时自动包含：

```bash
export BUILD_APKS=1
export INSTALL_APKS=1
./build.sh
```

### 方法 2: 手动安装

```bash
# 复制 APK 到路由器
scp out/packages/*.apk root@192.168.10.1:/tmp/

# SSH 登录路由器
ssh root@192.168.10.1

# 安装 APK 包
apk add --allow-untrusted /tmp/kms-server-1.0.0-r0_noarch.apk
apk add --allow-untrusted /tmp/nps-client-1.0.0-r0_noarch.apk
apk add --allow-untrusted /tmp/aria2-1.37.0-r1_aarch64.apk

# 启动服务
/etc/init.d/kms-server start
/etc/init.d/nps-client start
/etc/init.d/aria2 start

# 设置开机自启
rc-update add kms-server default
rc-update add nps-client default
rc-update add aria2 default
```

## 📖 使用示例

### KMS 激活

**Windows:**
```cmd
slmgr /skms 192.168.10.1:1688
slmgr /ato
```

**Office:**
```cmd
cscript ospp.vbs /sethst:192.168.10.1
cscript ospp.vbs /act
```

### NPS 内网穿透

1. 配置 NPS 服务器地址和验证密钥
2. 在 NPS 服务器端创建隧道
3. 启动服务访问内网资源

```bash
# 配置 NPS
cat > /etc/nps/npc.conf << EOF
server_addr=nps.example.com
server_port=8024
vkey=your-verify-key
conn_type=tcp
auto_reconnect=true
EOF

# 启动服务
/etc/init.d/nps-client start
```

### Aria2 下载

```bash
# 命令行下载
aria2c -x 16 -s 16 https://example.com/file.zip

# BT 下载
aria2c --bt-seed-untrue=true torrent.torrent

# 通过 Web UI 管理
# 访问 ClawUI -> Aria2 应用
```

## 🛠️ 开发新应用

### 1. 创建应用目录

```bash
mkdir -p clawui/apps/myapp/{www,api,i18n}
```

### 2. 创建 APKBUILD

```bash
cat > clawui/apps/myapp/APKBUILD << 'EOF'
pkgname=myapp
pkgver=1.0.0
pkgrel=0
pkgdesc="My ClawUI Application"
url="https://github.com/openclaw/clawui"
arch="noarch"
license="MIT"
depends="clawui"

package() {
    mkdir -p "$pkgdir/usr/share/clawui/apps/myapp"
    cp -r "$srcdir"/www/* "$pkgdir/usr/share/clawui/apps/myapp/"
    cp "$srcdir"/manifest.json "$pkgdir/usr/share/clawui/apps/myapp/"
}

sha512sums=""
EOF
```

### 3. 创建其他文件

- `manifest.json` - 应用清单
- `www/index.html` - Web 界面
- `api/handler.sh` - API 处理
- `myapp.init` - OpenRC 启动脚本

### 4. 构建

```bash
./scripts/build-apk-simple.sh build myapp
```

## 📊 构建输出

```
out/
├── packages/              # APK 包目录
│   ├── kms-server-1.0.0-r0_noarch.apk
│   ├── nps-client-1.0.0-r0_noarch.apk
│   └── aria2-1.37.0-r1_aarch64.apk
├── ax6600-alpine-factory.bin  # 完整固件
└── flash-commands.txt     # 刷写命令
```

## 🔍 故障排查

### 检查服务状态

```bash
rc-status | grep -E "kms|nps|aria2"
```

### 查看日志

```bash
tail -f /var/log/kms-server.log
tail -f /var/log/nps-client.log
tail -f /var/log/aria2.log
```

### 重启服务

```bash
/etc/init.d/kms-server restart
/etc/init.d/nps-client restart
/etc/init.d/aria2 restart
```

### 检查 APK 内容

```bash
tar -tzf out/packages/kms-server-1.0.0-r0_noarch.apk
```

## 📝 下一步

1. ✅ 构建并测试 APK 包
2. ✅ 集成到固件构建流程
3. ⏳ 添加更多应用（FTP、SMB、Transmission 等）
4. ⏳ 创建应用商店界面
5. ⏳ 实现自动更新机制

## 📚 相关文档

- [ClawUI 应用开发指南](clawui/apps/README.md)
- [APKBUILD 格式参考](https://wiki.alpinelinux.org/wiki/APKBUILD_Reference)
- [OpenRC 服务管理](https://wiki.alpinelinux.org/wiki/OpenRC)

---

**构建快乐！** ⚡🚀
