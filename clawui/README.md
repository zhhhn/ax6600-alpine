# ClawUI - Alpine Router Web Interface

类似 OpenWrt LuCI 的 Web 管理界面，支持 apk 包管理。

## 截图

```
┌─────────────────────────────────────────────────────────────┐
│ ⚡ ClawUI v1.0     状态 网络 无线 防火墙 软件包 系统   ax6600 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  系统状态                                                    │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────┐│
│  │ 系统信息          │ │ 资源使用          │ │ 网络流量      ││
│  │ 主机名: ax6600   │ │ CPU: 15%         │ │ 下载: 1.2 GB ││
│  │ 运行: 2天 5小时  │ │ ████████░░        │ │ 上传: 0.8 GB ││
│  │ 内核: 6.6.22     │ │ 内存: 256/512MB  │ │ 客户端: 3    ││
│  │ Alpine: 3.19     │ │ ██████████░░░░    │ │              ││
│  └──────────────────┘ └──────────────────┘ └──────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 安装

### 从源码安装

```bash
cd clawui
make install
rc-service clawui start
```

### APK 包安装

```bash
apk add clawui
rc-service clawui start
```

## 访问

- Web UI: http://192.168.1.1
- 默认端口: 80

## 功能模块

### 状态 (Status)

- 系统信息
- CPU/内存使用
- 网络流量
- 已连接客户端

### 网络 (Network)

- LAN 设置 (IP, 子网)
- WAN 设置 (DHCP/静态/PPPoE)
- 接口状态

### 无线 (Wireless)

- 2.4GHz/5GHz 配置
- SSID, 密码, 信道
- WiFi 扫描
- 客户端列表

### 防火墙 (Firewall)

- 端口转发
- 流量规则
- NAT 设置

### 软件包 (Packages)

- 已安装软件列表
- 安装/卸载软件包
- 更新软件源
- 升级软件包

### 系统 (System)

- 主机名/时区设置
- 服务管理
- 配置备份/恢复
- 重启/恢复出厂

## API 文档

### REST API

```
GET  /api/status          # 系统状态
GET  /api/network         # 网络配置
POST /api/network         # 更新网络
GET  /api/wireless        # WiFi 状态
GET  /api/wireless/config # WiFi 配置
POST /api/wireless        # 更新 WiFi
GET  /api/firewall        # 防火墙状态
GET  /api/firewall/forwards # 端口转发列表
POST /api/firewall/forwards # 添加端口转发
GET  /api/packages        # 软件包列表
POST /api/packages/install # 安装软件包
POST /api/packages/remove  # 卸载软件包
GET  /api/system          # 系统信息
POST /api/system/reboot   # 重启
```

## 与 LuCI 对比

| 功能 | LuCI | ClawUI |
|------|------|--------|
| 状态概览 | ✅ luci-mod-status | ✅ /api/status |
| 网络配置 | ✅ luci-mod-network | ✅ /api/network |
| WiFi 配置 | ✅ luci-mod-wireless | ✅ /api/wireless |
| 防火墙 | ✅ luci-app-firewall | ✅ /api/firewall |
| 软件包 | ✅ luci-app-opkg | ✅ /api/packages |
| VPN | ✅ luci-app-openvpn | ✅ /api/vpn |
| 主题 | Bootstrap/Material | Bootstrap-like |
| 语言 | 多语言 | 中文/English |
| 配置系统 | UCI | 直接文件 |

## 扩展开发

### 添加新模块

1. 创建 API 脚本:

```bash
# /usr/share/clawui/api/mymodule.sh
case "$REQUEST_METHOD" in
    GET)
        echo '{"status": "ok"}'
        ;;
esac
```

2. 添加前端页面:

```html
<!-- /usr/share/clawui/www/index.html -->
<section id="page-mymodule" class="page">
    <h2>我的模块</h2>
    <!-- 内容 -->
</section>
```

3. 添加导航:

```html
<a href="#mymodule" class="nav-item" data-page="mymodule">我的模块</a>
```

## 文件结构

```
/usr/share/clawui/
├── www/                  # Web 根目录
│   ├── index.html        # 主页面
│   ├── css/              # 样式
│   ├── js/               # JavaScript
│   └── cgi-bin/          # CGI 脚本
├── api/                  # API 处理脚本
│   ├── status.sh
│   ├── network.sh
│   ├── wireless.sh
│   ├── firewall.sh
│   ├── packages.sh
│   └── system.sh
└── themes/               # 主题

/etc/clawui/
├── config                # 主配置
└── httpd.conf            # HTTP 服务器配置

/etc/init.d/
└── clawui                # Init 脚本
```

## 依赖

- busybox httpd (或 lighttpd)
- bash
- jq (可选，用于 JSON 处理)

## 许可证

MIT License