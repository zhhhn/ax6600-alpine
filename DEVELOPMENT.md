# AX6600 Alpine Linux 开发文档

## 目录

1. [功能开发进度](#功能开发进度)
2. [文件结构](#文件结构)
3. [使用指南](#使用指南)
4. [测试方法](#测试方法)
5. [虚拟环境](#虚拟环境)
6. [开发日志](#开发日志)

---

## 功能开发进度

### 完成状态：17/17 (100%) ✅

#### Phase 0: 基础功能 (P0) ✅

| 功能 | 文件 | 说明 |
|------|------|------|
| LED 控制 | `/etc/init.d/leds` | 电源灯、系统灯、WiFi 状态灯 |
| 恢复出厂 | `/usr/sbin/factory-reset` | 支持选择性保留配置 |
| 按钮控制 | `/etc/init.d/buttons` | Reset 长按 10 秒恢复出厂 |

#### Phase 1: 网络功能 (P1) ✅

| 功能 | 文件 | 说明 |
|------|------|------|
| WiFi 管理 | `/usr/sbin/wifi` | setup/up/down/status/scan |
| 端口转发 | `/usr/sbin/port-forward` | add/del/list/clear |
| 固件升级 | `/usr/sbin/sysupgrade` | 升级、备份、恢复配置 |
| PPPoE | `/usr/sbin/pppoe-setup` | 宽带拨号配置 |

#### Phase 2: 系统管理 (P2) ✅

| 功能 | 文件 | 说明 |
|------|------|------|
| Web UI | `/www/` + lighttpd | 状态、网络、WiFi、系统管理 |
| IPv6 | `/etc/init.d/ipv6` | NAT66、radvd、DHCPv6 |
| QoS | `/usr/sbin/qos` | 带宽控制、IP 限速 |
| UPnP | `/etc/init.d/upnp` | miniupnpd 自动端口映射 |

#### Phase 3: 安全功能 (P3) ✅

| 功能 | 文件 | 说明 |
|------|------|------|
| VPN | `/usr/sbin/vpn-setup` | OpenVPN、WireGuard 客户端 |
| 访客网络 | `/etc/init.d/guest-network` | 独立 SSID、网络隔离 |
| MAC 过滤 | `/usr/sbin/mac-filter` | 黑白名单 |

#### Phase 4: 进阶功能 (P4) ✅

| 功能 | 文件 | 说明 |
|------|------|------|
| USB | `/etc/init.d/usb` | 自动挂载 USB 存储 |
| 网络监控 | `/usr/sbin/network-monitor` | 流量统计、报告 |
| 定时任务 | cron | 标准 cron 支持 |

---

## 文件结构

```
rootfs-overlay/
├── etc/
│   ├── init.d/              # OpenRC 服务
│   │   ├── leds             # LED 控制
│   │   ├── buttons          # 按钮控制
│   │   ├── network          # 网络服务
│   │   ├── wifi             # WiFi 服务
│   │   ├── firewall         # 防火墙
│   │   ├── dnsmasq          # DHCP/DNS
│   │   ├── upnp             # UPnP
│   │   ├── ipv6             # IPv6
│   │   ├── guest-network    # 访客网络
│   │   ├── webui            # Web UI
│   │   └── usb              # USB 支持
│   ├── hostapd/             # WiFi 配置
│   ├── network/interfaces   # 网络接口
│   ├── nftables.conf        # 防火墙规则
│   └── dnsmasq.conf         # DHCP/DNS 配置
├── usr/sbin/                # 管理工具
│   ├── wifi                 # WiFi 管理
│   ├── port-forward         # 端口转发
│   ├── qos                  # 流量控制
│   ├── factory-reset        # 恢复出厂
│   ├── pppoe-setup          # PPPoE 配置
│   ├── sysupgrade           # 固件升级
│   ├── vpn-setup            # VPN 配置
│   ├── mac-filter           # MAC 过滤
│   └── network-monitor      # 网络监控
└── www/                     # Web UI
    ├── index.html           # 主页
    ├── style.css            # 样式
    └── cgi-bin/             # CGI 脚本
```

---

## 使用指南

### 基本命令

```bash
# WiFi 管理
wifi setup MyWiFi MyPassword   # 配置 SSID 和密码
wifi up/down                   # 开关 WiFi
wifi status                    # 查看状态
wifi scan                      # 扫描网络
wifi channel 6 36              # 设置信道

# 端口转发
port-forward add 8080 192.168.1.100 80   # 添加规则
port-forward del 8080                    # 删除规则
port-forward list                        # 列出规则

# QoS 流量控制
qos set 100 50                           # 设置带宽 (下载100M, 上传50M)
qos limit 192.168.1.50 10 5              # IP 限速
qos status                               # 查看状态

# PPPoE 拨号
pppoe-setup config username password     # 配置 PPPoE
pppoe-setup connect                      # 连接
pppoe-setup status                       # 状态

# VPN 配置
vpn-setup openvpn config server 1194     # OpenVPN
vpn-setup wireguard config wg0 endpoint  # WireGuard

# 恢复出厂
factory-reset                            # 恢复出厂设置
factory-reset --keep-wifi                # 保留 WiFi 配置

# 网络监控
network-monitor start                    # 开始监控
network-monitor report 24                # 24小时报告
```

### Web UI

访问 http://192.168.1.1 进入管理界面。

功能页面：
- 状态概览：CPU、内存、网络流量
- 网络设置：LAN/WAN/PPPoE
- WiFi 设置：SSID、密码、信道
- 系统管理：重启、升级、备份

---

## 测试方法

### 本地测试

```bash
# 运行所有测试 (45项)
./scripts/test-firmware.sh all

# 快速冒烟测试
./scripts/test-firmware.sh smoke

# 只测试脚本
./scripts/test-firmware.sh scripts

# 只测试 CGI
./scripts/test-firmware.sh cgi

# 只测试配置
./scripts/test-firmware.sh config
```

### 测试覆盖

| 类别 | 测试数 | 说明 |
|------|--------|------|
| 用户脚本 | 9 | wifi, port-forward, qos 等 |
| Init 脚本 | 11 | leds, network, wifi 等 |
| CGI 脚本 | 7 | stats, network, wifi 等 |
| 配置文件 | 18 | 网络、WiFi、防火墙配置 |
| **总计** | **45** | |

---

## 虚拟环境

### 方式一：Python 模拟器 (推荐)

最轻量，无需任何依赖。

```bash
# 启动模拟器
python3 scripts/simulate.py

# 访问
# Web UI: http://localhost:8080
# API: http://localhost:8080/api/stats
```

### 方式二：Docker 路由器

需要安装 Docker。

```bash
# 构建镜像
./scripts/router-sim.sh build

# 启动路由器
./scripts/router-sim.sh start

# 访问
# Web UI: http://localhost:8080
# SSH: ssh root@localhost -p 2222
```

### 方式三：QEMU 虚拟机

需要安装 QEMU，可启动真实固件。

```bash
# 安装依赖
sudo apt-get install qemu-system-arm qemu-utils

# 创建虚拟机
./scripts/vm.sh create

# 启动
./scripts/vm.sh start

# 刷入固件
./scripts/vm.sh flash out/ax6600-alpine-factory.bin
```

### 对比

| 方式 | 启动速度 | 真实性 | WiFi 模拟 |
|------|----------|--------|-----------|
| Python 模拟器 | ⚡ 秒级 | 低 | ❌ |
| Docker | ⚡ 秒级 | 中 | ❌ |
| QEMU | 🐢 分钟 | 高 | ❌ |

**注意：** 所有虚拟环境都无法模拟 ath11k WiFi 硬件。

---

## 开发日志

### 2026-03-29

- ✅ 完成全部 17 项功能开发
- ✅ 添加固件测试框架 (45 项测试)
- ✅ 添加虚拟路由器环境
- ✅ 构建成功：factory.bin (46MB)

### 2026-03-28

- ✅ 修复 GitHub Actions 构建问题
  - .gitignore 文件排除问题
  - mknod 权限问题
  - apk --no-scripts 支持
  - 内核编译优化
- ✅ 创建开发文档

---

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-03-29 | v1.0 | 完成 17 项功能，首次正式发布 |
| 2026-03-28 | v0.1 | 初始构建，修复 CI 问题 |

---

*本文档持续更新中*