# 应用生态

ClawUI 应用生态系统解决了 Alpine 没有类似 LuCI 应用包的问题。

## 概念对比

### OpenWrt 模式

```
apk add openvpn
        ↓
自动推荐 luci-app-openvpn
        ↓
Web UI 出现 OpenVPN 管理界面
```

### Alpine + ClawUI 模式

```
apk add openvpn
        ↓
手动安装 clawui-app-openvpn
        ↓
Web UI 出现 OpenVPN 管理界面
```

## 应用包命名

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| 核心应用 | 内置 | network, wireless |
| 可选应用 | `clawui-app-*` | clawui-app-openvpn |
| 语言包 | `clawui-i18n-*` | clawui-i18n-openvpn-zh-cn |

## 内置应用

| 应用 | 路径 | 功能 |
|------|------|------|
| 状态 | `/api/status` | 系统状态 |
| 网络 | `/api/network` | 网络配置 |
| 无线 | `/api/wireless` | WiFi 配置 |
| 防火墙 | `/api/firewall` | 防火墙规则 |
| 软件包 | `/api/packages` | APK 管理 |
| 系统 | `/api/system` | 系统设置 |
| DHCP | `/api/dhcp` | DHCP/DNS |
| QoS | `/api/qos` | 流量控制 |
| VPN | `/api/vpn` | VPN 配置 |

## 可选应用

### 应用列表

| 应用包 | 主包 | 功能 |
|--------|------|------|
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

### 安装示例

```bash
# WireGuard
apk add wireguard-tools
apk add clawui-app-wireguard

# Transmission
apk add transmission-daemon
apk add clawui-app-transmission

# Samba
apk add samba
apk add clawui-app-samba
```

## 应用结构

每个应用包含：

```
clawui-app-openvpn/
├── manifest.json     # 应用元数据
├── www/              # Web 界面
│   ├── index.html
│   └── app.js
├── api/              # 后端 API
│   └── openvpn.sh
├── i18n/             # 翻译
│   ├── en.json
│   └── zh-cn.json
└── APKBUILD          # Alpine 包定义
```

### manifest.json

```json
{
    "id": "openvpn",
    "name": "OpenVPN",
    "version": "1.0.0",
    "description": "OpenVPN 管理",
    "icon": "vpn",
    "category": "vpn",
    "depends": ["openvpn"],
    "provides": ["clawui-app-openvpn"]
}
```

## 应用开发

### 创建新应用

```bash
cd clawui/tools
./create-app.sh myapp "My Application"
```

### 开发流程

1. 创建应用目录结构
2. 编写 API 脚本
3. 编写前端界面
4. 添加翻译
5. 创建 APKBUILD
6. 构建测试

### API 规范

```bash
#!/bin/sh
# api/myapp.sh

case "$REQUEST_METHOD" in
    GET)
        echo "Content-Type: application/json"
        echo ""
        echo '{"status": "ok"}'
        ;;
    POST)
        # 处理 POST 请求
        ;;
esac
```

## 应用注册

安装后自动注册到 ClawUI：

```json
// /usr/share/clawui/apps/registry.json
{
    "apps": [
        {
            "id": "openvpn",
            "name": "OpenVPN",
            "icon": "vpn",
            "path": "/usr/share/clawui/apps/openvpn"
        }
    ]
}
```

## 与 LuCI 对比

| 功能 | LuCI | ClawUI |
|------|------|--------|
| 包名 | `luci-app-*` | `clawui-app-*` |
| 语言包 | `luci-i18n-*` | `clawui-i18n-*` |
| 配置 | UCI | 文件 |
| API | Lua | Shell |
| 自动推荐 | ✅ | ⚠️ 手动 |

## 未来计划

- [ ] apk 钩子：安装主包时提示安装 UI
- [ ] 应用商店：Web UI 内置商店
- [ ] 一键安装：同时安装主包和 UI

---

相关文档：
- [CLAWUI.md](CLAWUI.md) - Web 界面
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南