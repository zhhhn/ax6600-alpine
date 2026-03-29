# ClawUI Web 管理界面

ClawUI 是类似 OpenWrt LuCI 的 Web 管理界面，专门为 Alpine Linux 路由器设计。

## 功能概览

```
┌─────────────────────────────────────────────────────────────────┐
│ ⚡ ClawUI      状态  网络  无线  防火墙  软件包  系统          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  系统状态                                                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ CPU: 15%        │  │ 内存: 256/512MB │  │ 客户端: 3       │ │
│  │ ████████░░░░░░░░ │  │ ██████████░░░░░░ │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 访问方式

```
URL:    http://192.168.1.1
端口:   80 (默认)
用户名: root
密码:   空 (首次登录后设置)
```

## 功能模块

### 状态概览

- CPU 使用率
- 内存使用
- 网络流量
- 已连接客户端
- 系统信息

### 网络设置

| 功能 | 说明 |
|------|------|
| LAN 设置 | IP 地址、子网掩码 |
| WAN 设置 | DHCP/静态/PPPoE |
| 接口状态 | 查看所有网络接口 |

### 无线设置

| 功能 | 说明 |
|------|------|
| 2.4GHz | SSID、密码、信道 |
| 5GHz | SSID、密码、信道 |
| 客户端列表 | 已连接设备 |
| WiFi 扫描 | 扫描周围网络 |

### 防火墙

| 功能 | 说明 |
|------|------|
| 端口转发 | 添加/删除转发规则 |
| 流量规则 | 自定义防火墙规则 |
| NAT 设置 | NAT 配置 |

### 软件包

| 功能 | 说明 |
|------|------|
| 已安装包 | 查看已安装软件 |
| 可用包 | 浏览软件仓库 |
| 安装包 | 安装新软件 |
| 升级包 | 更新软件 |

### 系统管理

| 功能 | 说明 |
|------|------|
| 主机名 | 修改设备名称 |
| 时区 | 设置时区 |
| 服务管理 | 启停服务 |
| 配置备份 | 备份/恢复配置 |
| 固件升级 | 升级系统 |
| 恢复出厂 | 重置系统 |

## REST API

### API 端点

```
GET  /api/status          # 系统状态
GET  /api/network         # 网络配置
POST /api/network         # 更新网络
GET  /api/wireless        # WiFi 配置
POST /api/wireless        # 更新 WiFi
GET  /api/firewall        # 防火墙状态
GET  /api/firewall/forwards # 端口转发
POST /api/firewall/forwards # 添加转发
GET  /api/packages        # 软件包列表
POST /api/packages/install # 安装包
GET  /api/system          # 系统信息
POST /api/system/reboot   # 重启
```

### API 示例

```bash
# 获取系统状态
curl http://192.168.1.1/api/status

# 更新 WiFi SSID
curl -X POST http://192.168.1.1/api/wireless \
  -d '{"ssid":"MyWiFi","password":"password123"}'

# 添加端口转发
curl -X POST http://192.168.1.1/api/firewall/forwards \
  -d '{"proto":"tcp","ext_port":8080,"int_ip":"192.168.1.100","int_port":80}'

# 安装软件包
curl -X POST http://192.168.1.1/api/packages/install \
  -d '{"package":"htop"}'
```

## 命令行工具

ClawUI 集成了命令行工具，提供相同功能：

```bash
# WiFi 管理
wifi setup MyWiFi password123
wifi up
wifi status

# 端口转发
port-forward add 8080 192.168.1.100 80
port-forward list

# QoS
qos set 100 50

# 系统操作
factory-reset
sysupgrade firmware.bin
```

## 配置文件

### 主配置

`/etc/clawui/config`:
```
PORT=80
THEME=bootstrap
LANG=zh-cn
```

### HTTP 服务器

`/etc/clawui/httpd.conf`:
```
*.sh:/bin/sh
*.cgi:/bin/sh
I:index.html
```

## 主题

ClawUI 支持多种主题：

```bash
# 查看可用主题
ls /usr/share/clawui/themes/

# 切换主题
sed -i 's/THEME=.*/THEME=material/' /etc/clawui/config
rc-service clawui restart
```

## 与 LuCI 对比

| 功能 | LuCI | ClawUI |
|------|------|--------|
| 状态概览 | ✅ | ✅ |
| 网络配置 | ✅ | ✅ |
| WiFi 配置 | ✅ | ✅ |
| 防火墙 | ✅ | ✅ |
| 软件包管理 | ✅ opkg | ✅ apk |
| VPN 配置 | ✅ | ✅ |
| 应用生态 | ✅ luci-app-* | ✅ clawui-app-* |
| 主题 | Bootstrap/Material | Bootstrap-like |
| 配置系统 | UCI | 直接文件 |
| 国际化 | ✅ 多语言 | 中文/English |

## 开发文档

详见 [clawui/README.md](../clawui/README.md)。

---

相关文档：
- [APPS.md](APPS.md) - 应用生态
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南