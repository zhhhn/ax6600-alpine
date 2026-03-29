# ClawUI - Alpine Router Web Interface

类似 OpenWrt LuCI 的 Web 管理界面框架。

## 架构设计

### 核心组件

```
/usr/share/clawui/
├── core/                    # 核心框架
│   ├── dispatcher.lua       # 请求分发器
│   ├── template.lua         # 模板引擎
│   ├── uci.lua             # 配置管理
│   └── i18n.lua            # 国际化
├── view/                    # 视图模板
│   ├── header.htm
│   ├── footer.htm
│   └── themes/
└── controller/              # 控制器
    ├── index.lua
    ├── network.lua
    ├── wireless.lua
    └── system.lua

/usr/lib/lua/clawui/         # 模块
├── model/                   # 数据模型
│   ├── network.lua
│   ├── wireless.lua
│   └── firewall.lua
└── controller/              # 控制器模块
    ├── admin/
    │   ├── network.lua
    │   ├── wireless.lua
    │   ├── firewall.lua
    │   └── system.lua
    └── status.lua
```

### MVC 架构

```
请求 → Dispatcher → Controller → Model → View → 响应
         ↓              ↓          ↓
      路由解析      业务逻辑   数据操作
```

## API 设计

### REST API

```
GET    /api/status              # 系统状态
GET    /api/network             # 网络配置
POST   /api/network             # 更新网络
GET    /api/wireless            # WiFi 配置
POST   /api/wireless            # 更新 WiFi
GET    /api/firewall            # 防火墙规则
POST   /api/firewall            # 添加规则
DELETE /api/firewall/:id        # 删除规则
GET    /api/packages            # 软件包列表
POST   /api/packages/install    # 安装包
POST   /api/packages/remove     # 卸载包
```

## 模块对应

### LuCI → ClawUI 对应表

| LuCI 模块 | ClawUI 模块 | Alpine 包 | 功能 |
|-----------|-------------|-----------|------|
| luci-mod-status | status | - | 系统状态 |
| luci-mod-system | system | - | 系统设置 |
| luci-mod-network | network | iproute2, bridge-utils | 网络配置 |
| luci-mod-wireless | wireless | hostapd, wpa_supplicant | WiFi 配置 |
| luci-app-firewall | firewall | nftables, iptables | 防火墙 |
| luci-app-dnsmasq | dns-dhcp | dnsmasq | DNS/DHCP |
| luci-app-openvpn | openvpn | openvpn | VPN |
| luci-app-wireguard | wireguard | wireguard-tools | WireGuard |
| luci-app-qos | qos | tc, iproute2 | QoS |
| luci-app-ddns | ddns | ddns-scripts | 动态DNS |

## 前端框架

使用轻量级方案：

```
/lib/              # 第三方库
├── vue.min.js     # Vue.js 3.x (CDN)
├── axios.min.js   # HTTP 客户端
└── chart.min.js   # 图表

/css/
├── clawui.css     # 主样式
└── themes/        # 主题

/js/
├── app.js         # 主应用
├── api.js         # API 封装
├── i18n.js        # 国际化
└── components/    # 组件
    ├── status.js
    ├── network.js
    └── wireless.js
```

## 部署

### 安装

```bash
apk add clawui clawui-theme-bootstrap
```

### 启动

```bash
rc-service clawui start
rc-update add clawui
```

### 配置

/etc/clawui/config:
```
listen=0.0.0.0:80
theme=bootstrap
lang=zh-cn
```