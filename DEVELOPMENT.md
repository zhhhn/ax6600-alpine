# JDCloud AX6600 Alpine Linux 开发文档

## 项目目标

将完整的 Alpine Linux 系统移植到京东云 AX6600 路由器，实现 OpenWrt 的所有核心功能。

---

## 功能开发进度

### Phase 0: 基础功能 (P0) ✅

#### 1.1 LED 指示灯控制 ✅

**实现：** `/etc/init.d/leds`
- 支持电源灯、系统灯、WiFi 状态灯
- 系统灯呼吸效果
- WiFi 状态自动同步

#### 1.2 恢复出厂设置 ✅

**实现：** `/usr/sbin/factory-reset`
- 支持选择性保留配置
- 自动备份
- 支持 dry-run 预览

#### 1.3 按钮控制 ✅

**实现：** `/etc/init.d/buttons`
- Reset 按钮长按 10 秒恢复出厂
- WPS 按钮支持
- GPIO 监控守护进程

---

### Phase 1: 网络功能 (P1) ✅

#### 2.1 WiFi 配置脚本 ✅

**实现：** `/usr/sbin/wifi`
```bash
wifi setup <ssid> <password>   # 配置
wifi up/down                    # 开关
wifi status                     # 状态
wifi scan                       # 扫描
wifi channel <2g> <5g>          # 信道
wifi hide/show                  # 隐藏/显示 SSID
```

#### 2.2 端口转发管理 ✅

**实现：** `/usr/sbin/port-forward`
```bash
port-forward add <端口> <IP> <内网端口> [tcp/udp]
port-forward del <端口>
port-forward list
port-forward clear
```

#### 2.3 固件升级脚本 ✅

**实现：** `/usr/sbin/sysupgrade`
```bash
sysupgrade <固件>              # 升级（保留配置）
sysupgrade -n <固件>           # 升级（清除配置）
sysupgrade -b                  # 备份配置
sysupgrade -r                  # 恢复配置
sysupgrade -c <固件>           # 校验固件
```

#### 2.4 PPPoE 拨号支持 ✅

**实现：** `/usr/sbin/pppoe-setup`
```bash
pppoe-setup config <用户名> <密码>
pppoe-setup connect/disconnect
pppoe-setup status
```

---

### Phase 2: 系统管理 (P2) ✅

#### 3.1 Web 管理界面 ✅

**实现：** `/www/` + `/etc/init.d/webui`
- 状态概览（CPU、内存、网络）
- 网络配置（LAN/WAN/PPPoE）
- WiFi 配置
- 系统管理（重启、备份、升级）
- 响应式设计，支持移动端

**CGI 脚本：**
- `stats.cgi` - 状态 API
- `network.cgi` - 网络设置
- `wifi.cgi` - WiFi 设置
- `system.cgi` - 系统设置
- `password.cgi` - 密码修改
- `factory-reset.cgi` - 恢复出厂
- `reboot.cgi` - 重启

#### 3.2 IPv6 支持 ✅

**实现：** `/etc/init.d/ipv6`
- IPv6 NAT66
- radvd 路由通告
- DHCPv6 支持

#### 3.3 QoS/流量控制 ✅

**实现：** `/usr/sbin/qos`
```bash
qos set <下载> <上传>          # 设置带宽
qos priority <IP> <级别>       # IP 优先级
qos limit <IP> <下载> <上传>   # IP 限速
qos clear/status
```

#### 3.4 UPnP 支持 ✅

**实现：** `/etc/init.d/upnp`
- miniupnpd 配置
- 自动端口映射

---

### Phase 3: 安全增强 (P3) ✅

#### 4.1 VPN 客户端 ✅

**实现：** `/usr/sbin/vpn-setup`
```bash
vpn-setup openvpn config <服务器> <端口>
vpn-setup wireguard config <接口> <端点>
```
- OpenVPN 客户端
- WireGuard 客户端
- 密钥生成

#### 4.2 访客网络 ✅

**实现：** `/etc/init.d/guest-network`
- 独立 SSID
- 网络隔离（无法访问主 LAN）
- 独立 DHCP

#### 4.3 MAC 过滤 ✅

**实现：** `/usr/sbin/mac-filter` + `/etc/init.d/mac-filter`
```bash
mac-filter add/del <MAC>
mac-filter mode whitelist/blacklist
mac-filter list
```

---

### Phase 4: 进阶功能 (P4) ✅

#### 5.1 USB 支持 ✅

**实现：** `/etc/init.d/usb`
- 自动挂载 USB 存储
- 支持多种文件系统（vfat, ntfs-3g, ext4）

#### 5.2 网络监控 ✅

**实现：** `/usr/sbin/network-monitor`
```bash
network-monitor start/stop
network-monitor report [小时]
network-monitor top
```
- 流量统计
- 历史报告

#### 5.3 定时任务 ✅

通过标准 cron 实现（`apk add cron`）

---

## 开发进度总结

| Phase | 功能数 | 完成数 | 状态 |
|-------|--------|--------|------|
| P0 基础 | 3 | 3 | ✅ 100% |
| P1 网络 | 4 | 4 | ✅ 100% |
| P2 系统 | 4 | 4 | ✅ 100% |
| P3 安全 | 3 | 3 | ✅ 100% |
| P4 进阶 | 3 | 3 | ✅ 100% |
| **总计** | **17** | **17** | ✅ **100%** |

---

## 文件结构

```
rootfs-overlay/
├── etc/
│   ├── init.d/
│   │   ├── leds           # LED 控制
│   │   ├── buttons        # 按钮控制
│   │   ├── upnp           # UPnP
│   │   ├── ipv6           # IPv6
│   │   ├── guest-network  # 访客网络
│   │   ├── mac-filter     # MAC 过滤
│   │   ├── webui          # Web UI
│   │   └── usb            # USB 支持
│   ├── hostapd/           # WiFi 配置
│   └── network/
├── usr/
│   └── sbin/
│       ├── wifi           # WiFi 管理
│       ├── port-forward   # 端口转发
│       ├── sysupgrade     # 固件升级
│       ├── pppoe-setup    # PPPoE
│       ├── qos            # QoS
│       ├── factory-reset  # 恢复出厂
│       ├── mac-filter     # MAC 过滤
│       ├── vpn-setup      # VPN 配置
│       └── network-monitor # 网络监控
└── www/
    ├── index.html         # Web 主页
    ├── style.css          # 样式
    └── cgi-bin/           # CGI 脚本
        ├── stats.cgi
        ├── network.cgi
        ├── wifi.cgi
        ├── system.cgi
        ├── password.cgi
        ├── factory-reset.cgi
        └── reboot.cgi
```

---

## 使用指南

### 基本命令

```bash
# WiFi 管理
wifi setup MyWiFi MyPassword
wifi status

# 端口转发
port-forward add 8080 192.168.1.100 80
port-forward list

# QoS
qos set 100 50
qos limit 192.168.1.50 10 5

# 恢复出厂
factory-reset

# 网络监控
network-monitor start
network-monitor report 24

# VPN
vpn-setup wireguard config wg0 my.vpn.server:51820
vpn-setup openvpn config vpn.example.com 1194
```

### Web 管理

访问 `http://192.168.1.1/` 进入 Web 管理界面。

---

## 更新日志

| 日期 | 更新内容 |
|------|----------|
| 2026-03-29 | 完成所有 17 项功能开发 |
| 2026-03-28 | 创建开发文档，修复构建问题 |

---

*本文档已完成更新*