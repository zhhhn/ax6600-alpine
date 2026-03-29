# JDCloud AX6600 Alpine Linux Router

> 企业级路由器固件，基于 Alpine Linux，实现 OpenWrt 同等功能

[![Build](https://github.com/zhhhn/ax6600-alpine/actions/workflows/build.yml/badge.svg)](https://github.com/zhhhn/ax6600-alpine/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## 📖 项目简介

将完整的 Alpine Linux 系统移植到京东云 AX6600 路由器，提供类似 OpenWrt 的功能和体验。

### 核心特性

- **完整 Linux 系统** — Alpine Linux 3.19 + Linux 6.6.22 LTS
- **Web 管理界面** — ClawUI，类似 LuCI 的现代化界面
- **17 项路由功能** — 覆盖网络、安全、系统管理
- **应用生态** — 可扩展的 Web UI 应用系统
- **APK 包管理** — 直接使用 Alpine 软件仓库

---

## 🖥️ 硬件支持

### 支持设备

| 设备 | 芯片 | 内存 | 网络 | 状态 |
|------|------|------|------|------|
| 京东云 AX6600 | IPQ6010 (4×A53@1.8GHz) | 512MB | 1×2.5G + 4×1G | ✅ |

### 硬件规格

```
SoC:     Qualcomm IPQ6010
CPU:     4× Cortex-A53 @ 1.8GHz
内存:    512MB DDR4
存储:    eMMC
WiFi:    2×2 MU-MIMO 2.4GHz + 4×4 MU-MIMO 5GHz (ath11k)
网络:    1×2.5G WAN (eth0) + 4×1G LAN (eth1-4, br-lan)
```

---

## 📦 固件下载

### 从 GitHub Releases 下载

每次推送到 main 分支会自动构建，可在 [Releases](https://github.com/zhhhn/ax6600-alpine/releases) 页面下载。

### 构建产物

| 文件 | 大小 | 说明 |
|------|------|------|
| `ax6600-alpine-factory.bin` | ~46MB | 完整刷机包 |
| `ax6600-alpine.itb` | ~14MB | FIT 镜像 (kernel + dtb) |
| `alpine-rootfs.tar.gz` | ~33MB | 根文件系统 |
| `modules.tar.gz` | ~69MB | 内核模块 |

---

## 🚀 快速开始

### 构建固件

```bash
# 克隆仓库
git clone https://github.com/zhhhn/ax6600-alpine.git
cd ax6600-alpine

# 本地构建 (需要 Ubuntu/Debian)
sudo apt-get install build-essential flex bison gcc-aarch64-linux-gnu
./build.sh

# 输出文件
ls -lh out/
```

### 刷入设备

```bash
# U-Boot TFTP 刷写
setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10
tftpboot 0x44000000 ax6600-alpine-factory.bin
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000
reset
```

### 首次登录

```
Web UI:  http://192.168.1.1
SSH:     ssh root@192.168.1.1
WiFi:    AX6600 / admin123
```

---

## 🏗️ 项目架构

```
ax6600-alpine/
├── .github/workflows/       # GitHub Actions CI/CD
│   └── build.yml            # 自动构建配置
│
├── configs/                 # 设备树和内核配置
│   └── ipq6018-jdcloud-ax6600.dts
│
├── scripts/                 # 构建脚本
│   ├── build-kernel.sh      # 内核编译
│   ├── build-rootfs.sh      # 根文件系统构建
│   ├── package-firmware.sh  # 固件打包
│   ├── test-firmware.sh     # 测试框架
│   └── vm.sh                # QEMU 虚拟机
│
├── rootfs-overlay/          # 文件系统覆盖层
│   ├── etc/                 # 配置文件
│   │   ├── init.d/          # OpenRC 服务
│   │   ├── network/         # 网络配置
│   │   ├── hostapd/         # WiFi 配置
│   │   └── clawui/          # ClawUI 配置
│   ├── usr/sbin/            # 管理工具
│   └── www/                 # ClawUI Web 界面
│
├── clawui/                  # Web 管理界面系统
│   ├── www/                 # 前端代码
│   ├── api/                 # REST API
│   └── apps/                # 可选应用
│
├── build.sh                 # 主构建入口
├── README.md                # 本文档
└── DEVELOPMENT.md           # 开发文档
```

---

## ⚡ 功能列表

### 已实现功能 (17项)

#### 网络功能

| 功能 | 命令 | Web UI |
|------|------|--------|
| WiFi 管理 | `wifi setup/up/down/status` | ✅ 无线设置 |
| 端口转发 | `port-forward add/del/list` | ✅ 防火墙 |
| PPPoE 拨号 | `pppoe-setup config` | ✅ 网络设置 |
| IPv6 支持 | `/etc/init.d/ipv6` | ✅ 网络设置 |
| QoS 流量控制 | `qos set <down> <up>` | ✅ QoS |
| UPnP | `/etc/init.d/upnp` | ✅ 服务管理 |

#### 系统管理

| 功能 | 命令 | Web UI |
|------|------|--------|
| Web 管理界面 | http://192.168.1.1 | ✅ ClawUI |
| 系统状态 | — | ✅ 首页 |
| 服务管理 | `rc-service <svc> start/stop` | ✅ 系统 |
| 固件升级 | `sysupgrade <file>` | ✅ 系统 |
| 恢复出厂 | `factory-reset` | ✅ 系统 |
| 配置备份 | `sysupgrade -b` | ✅ 系统 |

#### 安全功能

| 功能 | 命令 | Web UI |
|------|------|--------|
| 防火墙 | nftables | ✅ 防火墙 |
| VPN 客户端 | `vpn-setup openvpn/wireguard` | ✅ VPN |
| 访客网络 | `/etc/init.d/guest-network` | ✅ 无线 |
| MAC 过滤 | `mac-filter add/del` | ✅ 无线 |

#### 进阶功能

| 功能 | 命令 | Web UI |
|------|------|--------|
| USB 存储 | `/etc/init.d/usb` | — |
| 网络监控 | `network-monitor start/report` | ✅ 状态 |
| LED 控制 | `/etc/init.d/leds` | — |
| 按钮控制 | `/etc/init.d/buttons` | — |

---

## 🖼️ ClawUI Web 界面

### 界面预览

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
│  网络流量: 下载 1.2GB / 上传 0.8GB                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### REST API

```
GET  /api/status          # 系统状态
GET  /api/network         # 网络配置
POST /api/network         # 更新网络
GET  /api/wireless        # WiFi 配置
POST /api/wireless        # 更新 WiFi
GET  /api/firewall        # 防火墙状态
POST /api/firewall/forwards # 添加端口转发
GET  /api/packages        # 软件包列表
POST /api/packages/install # 安装软件包
GET  /api/system          # 系统信息
POST /api/system/reboot   # 重启
```

---

## 🔌 应用生态

### 内置应用

| 应用 | 功能 |
|------|------|
| 状态 | CPU、内存、流量、客户端 |
| 网络 | LAN/WAN/PPPoE 配置 |
| 无线 | 2.4GHz/5GHz WiFi 配置 |
| 防火墙 | 端口转发、NAT 规则 |
| 软件包 | APK 安装/卸载/升级 |
| 系统 | 服务管理、备份、重启 |

### 可选应用 (clawui-app-*)

已开发 9 个 Web 管理应用，每个应用提供完整的 Web 界面：

| 应用 | 包名 | 功能 | 依赖 |
|------|------|------|------|
| **Aria2** | `clawui-app-aria2` | BT/HTTP 下载管理 | aria2, curl |
| **NPS 服务端** | `clawui-app-nps` | 内网穿透服务器 | nps |
| **NPC 客户端** | `clawui-app-npc` | 内网穿透客户端 | npc |
| **KMS** | `clawui-app-kms` | Windows/Office 激活 | py3-kms |
| **FRP** | `clawui-app-frp` | FRP 穿透客户端 | frpc |
| **Transmission** | `clawui-app-transmission` | BT 下载 | transmission |
| **AdGuard Home** | `clawui-app-adguard` | DNS 广告过滤 | adguardhome |
| **FTP** | `clawui-app-vsftpd` | FTP 文件服务 | vsftpd |
| **Samba** | `clawui-app-samba` | 文件共享 | samba |

### 安装示例

```bash
# 1. 安装服务 (从 Alpine 官方源)
apk add aria2

# 2. 安装 Web 管理界面
apk add --allow-untrusted clawui-app-aria2-1.0.0-r0_noarch.apk

# 3. 启动服务
/etc/init.d/aria2 start
rc-update add aria2 default

# 4. Web 访问
http://192.168.1.1/app/clawui-app-aria2
```

### 应用构建

```bash
cd clawui/apps

# 构建所有应用
../scripts/build-managers.sh all

# 构建单个应用
../scripts/build-managers.sh build clawui-app-aria2

# 输出目录
ls ../out/packages/
```

📚 **详细文档**: [clawui-apps/README.md](clawui-apps/README.md)

---

## 🧪 测试与开发

### 本地测试

```bash
# 运行所有测试 (45项)
./scripts/test-firmware.sh all

# 快速语法检查
./scripts/test-firmware.sh smoke
```

### 虚拟环境

```bash
# Python 模拟器 (轻量)
python3 scripts/simulate.py
# 访问 http://localhost:8080

# QEMU 虚拟机 (完整)
./scripts/vm.sh create
./scripts/vm.sh start
```

---

## 📚 文档

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目概述 |
| [DEVELOPMENT.md](DEVELOPMENT.md) | 开发指南、功能列表 |
| [clawui/README.md](clawui/README.md) | Web 界面文档 |
| [clawui/APPS.md](clawui/APPS.md) | 应用开发指南 |

---

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

### 开发流程

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing`)
5. 创建 Pull Request

### 代码规范

- Shell 脚本使用 `#!/bin/sh` 或 `#!/bin/bash`
- 使用 `shellcheck` 检查脚本语法
- API 返回 JSON 格式

---

## ⚠️ 免责声明

- **刷机有风险**，可能导致设备变砖
- **失去保修**，刷机后不再享受官方保修
- **备份 ART**，请备份 WiFi 校准数据分区
- **作者不对任何损失负责**

---

## 📄 许可证

- 内核代码: GPL v2
- Alpine Linux: MIT
- 构建脚本: MIT
- ClawUI: MIT

---

## 🙏 致谢

- [Alpine Linux](https://alpinelinux.org/) - 轻量级 Linux 发行版
- [OpenWrt](https://openwrt.org/) - 路由器固件参考
- [LuCI](https://github.com/openwrt/luci) - Web 界面灵感
- [Qualcomm](https://www.qualcomm.com/) - IPQ6010 SDK 参考

---

**Made with ⚡ by router enthusiasts**