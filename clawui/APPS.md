# ClawUI 应用生态系统

## 概述

ClawUI 应用系统解决了 Alpine 没有 LuCI 生态的问题。

## 核心机制

### 1. 应用包命名

```
原包: wireguard-tools
ClawUI UI: clawui-app-wireguard
语言包: clawui-i18n-wireguard-zh-cn
```

### 2. 应用结构

```
clawui-app-wireguard/
├── APKBUILD              # Alpine 包定义
├── manifest.json         # 应用元数据
├── www/                  # Web 界面
│   ├── index.html
│   └── app.js
├── api/                  # API 端点
│   └── wireguard.sh
├── i18n/                 # 翻译
│   ├── en.json
│   └── zh-cn.json
└── post-install          # 安装后钩子
```

### 3. 安装流程

```
用户: apk add wireguard-tools
      ↓
ClawUI 检测到 wireguard 已安装
      ↓
提示: "检测到 WireGuard，是否安装管理界面?"
      ↓
用户确认: apk add clawui-app-wireguard
      ↓
应用自动注册到 ClawUI
      ↓
用户可以在 Web UI 看到 WireGuard 管理界面
```

## 应用注册

安装后自动注册到 `/usr/share/clawui/apps/registry.json`:

```json
{
  "apps": [
    {
      "id": "wireguard",
      "name": "WireGuard",
      "icon": "shield",
      "category": "vpn",
      "path": "/usr/share/clawui/apps/wireguard"
    }
  ]
}
```

## 应用 API

每个应用提供自己的 API：

```
/api/apps/wireguard/           # 状态
/api/apps/wireguard/interfaces # 接口列表
/api/apps/wireguard/interfaces/wg0  # 接口详情
```

## 应用开发

### 创建新应用

```bash
cd clawui/tools
./create-app.sh myapp "My Application"
```

### 应用模板

```bash
apps/
├── wireguard/
│   ├── APKBUILD
│   ├── manifest.json
│   ├── api/
│   ├── www/
│   └── i18n/
├── openvpn/
├── transmission/
└── ...
```

## 应用列表

### 内置应用 (核心功能)

| 应用 | 功能 |
|------|------|
| network | 网络设置 |
| wireless | 无线设置 |
| firewall | 防火墙 |
| dhcp | DHCP/DNS |
| system | 系统设置 |

### 可选应用 (需安装)

| 应用包 | 依赖包 | 功能 |
|--------|--------|------|
| clawui-app-wireguard | wireguard-tools | WireGuard VPN |
| clawui-app-openvpn | openvpn | OpenVPN |
| clawui-app-transmission | transmission-daemon | BT下载 |
| clawui-app-aria2 | aria2 | 多协议下载 |
| clawui-app-samba | samba | 文件共享 |
| clawui-app-frp | frp | 内网穿透 |
| clawui-app-adblock | adguardhome | 广告过滤 |
| clawui-app-ddns | ddns-scripts | 动态DNS |
| clawui-app-tor | tor | Tor代理 |
| clawui-app-vsftpd | vsftpd | FTP服务器 |
| clawui-app-nginx | nginx | Web服务器 |

## 安装示例

### WireGuard

```bash
# 安装 WireGuard
apk add wireguard-tools

# 安装 ClawUI 界面
apk add clawui-app-wireguard

# 启动服务
rc-service wireguard start

# 访问 Web UI
http://192.168.1.1 → 应用 → WireGuard
```

### Transmission

```bash
apk add transmission-daemon
apk add clawui-app-transmission
rc-service transmission start
```

## 与 OpenWrt 对比

| 特性 | OpenWrt | ClawUI |
|------|---------|--------|
| 包管理器 | opkg | apk |
| Web UI | LuCI | ClawUI |
| 应用包 | luci-app-* | clawui-app-* |
| 语言包 | luci-i18n-* | clawui-i18n-* |
| 依赖自动安装 | ✅ | ⚠️ 需手动安装 UI 包 |

## 未来计划

1. **apk 钩子** - 安装主包时自动提示安装 UI
2. **应用商店** - Web UI 内置应用商店
3. **一键安装** - 同时安装主包和 UI 包
4. **社区仓库** - 提供社区贡献的应用