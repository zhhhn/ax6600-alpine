# ClawUI 应用包 (clawui-app-*)

## ✅ 正确的包命名

根据 ClawUI 开发文档，应用包的命名格式为：**`clawui-app-xxx`**

例如：
- `clawui-app-aria2` - Aria2 下载管理器
- `clawui-app-nps` - NPS 内网穿透
- `clawui-app-kms` - KMS 激活服务器

## 📦 已开发应用

| 应用 | 包名 | APK 大小 | 依赖 | 功能 |
|------|------|---------|------|------|
| Aria2 | clawui-app-aria2 | 6.7K | aria2, curl | 下载管理、进度查看、配置 |
| NPS | clawui-app-nps | 3.4K | npc | 内网穿透配置、隧道管理 |
| KMS | clawui-app-kms | 3.2K | py3-kms | KMS 服务器、激活命令 |

## 🎯 架构说明

```
Alpine 官方源
    ↓ (apk install)
/usr/bin/aria2c, /usr/bin/npc, /usr/bin/py-kms
    ↓ (OpenRC 服务)
/etc/init.d/aria2, /etc/init.d/npc, /etc/init.d/py-kms
    ↓ (ClawUI 管理界面)
clawui-app-aria2, clawui-app-nps, clawui-app-kms
    ↓ (用户访问)
http://192.168.1.1/app/clawui-app-aria2
```

## 🚀 使用方式

```bash
# 1. 安装官方应用
apk add aria2

# 2. 安装 ClawUI 管理界面
apk add --allow-untrusted clawui-app-aria2-1.0.0-r0_noarch.apk

# 3. 启动服务
/etc/init.d/aria2 start
rc-update add aria2 default

# 4. Web 访问
http://192.168.1.1/app/clawui-app-aria2
```

## 📁 包结构

```
clawui-app-aria2.apk
├── .PKGINFO
└── usr/
    └── share/
        └── clawui/
            └── apps/
                └── clawui-app-aria2/
                    ├── manifest.json      # 应用清单
                    ├── www/
                    │   └── index.html     # Web 界面
                    ├── api/
                    │   └── handler.sh     # API 处理
                    └── i18n/
                        └── translations.json
```

## 🔧 构建命令

```bash
# 构建所有应用
./scripts/build-managers.sh all

# 构建单个应用
./scripts/build-managers.sh build clawui-app-aria2
```

## 📋 与现有应用对比

| 类型 | 包名前缀 | 示例 | 说明 |
|------|---------|------|------|
| **ClawUI 应用** | `clawui-app-*` | clawui-app-aria2 | Web 管理界面 |
| ClawUI 核心 | `clawui` | clawui | 主界面 |
| Alpine 官方 | 应用名 | aria2, npc, py-kms | 实际服务 |
| OpenWrt/LuCI | `luci-app-*` | luci-app-aria2 | 类似概念 |

## 🎨 应用功能

### clawui-app-aria2
- ✅ 添加下载（HTTP/FTP/BT/Magnet）
- ✅ 实时进度和速度
- ✅ 暂停/继续/删除
- ✅ 配置管理
- ✅ 服务控制
- ✅ 日志查看

### clawui-app-nps
- ✅ 配置服务器地址、端口、vkey
- ✅ 服务启动/停止
- ✅ 隧道状态
- ✅ 日志查看

### clawui-app-kms
- ✅ 配置监听端口
- ✅ 服务控制
- ✅ 激活统计
- ✅ Windows/Office 激活命令
- ✅ 日志查看

## 📊 开发进度

### 已完成
- ✅ clawui-app-aria2
- ✅ clawui-app-nps
- ✅ clawui-app-kms

### 计划中
- ⏳ clawui-app-frp (FRP 反向代理)
- ⏳ clawui-app-transmission (BT 下载)
- ⏳ clawui-app-adguard (广告过滤)
- ⏳ clawui-app-vsftpd (FTP 服务器)
- ⏳ clawui-app-samba (文件共享)

## 💡 开发指南

### 1. 创建目录

```bash
mkdir -p clawui/apps/clawui-app-myapp/{www,api,i18n}
```

### 2. 创建 manifest.json

```json
{
  "id": "clawui-app-myapp",
  "name": "MyApp",
  "version": "1.0.0",
  "description": "MyApp Web 管理界面",
  "icon": "star",
  "category": "tools",
  "dependencies": ["myapp"]
}
```

### 3. 创建 APKBUILD

```bash
pkgname=clawui-app-myapp
pkgver=1.0.0
pkgrel=0
pkgdesc="ClawUI web management interface for myapp"
arch="noarch"
license="MIT"
depends="clawui myapp"
```

### 4. 构建

```bash
./scripts/build-managers.sh build clawui-app-myapp
```

## 📚 相关文档

- [CLAWUI.md](docs/CLAWUI.md) - ClawUI 主界面文档
- [APPS.md](clawui/APPS.md) - ClawUI 应用生态
- [README.md](clawui/README.md) - ClawUI 开发指南

---

**包命名已更正为 `clawui-app-xxx` 格式！** ⚡
