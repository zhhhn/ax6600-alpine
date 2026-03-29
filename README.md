# JDCloud AX6600 Alpine Linux

> 将完整 Alpine Linux 移植到京东云 AX6600 路由器，实现 OpenWrt 同等功能

[![Build](https://github.com/zhhhn/ax6600-alpine/actions/workflows/build.yml/badge.svg)](https://github.com/zhhhn/ax6600-alpine/actions)

---

## 📋 项目概述

基于 Alpine Linux 构建的路由器固件，支持所有 OpenWrt 核心功能。

### 硬件规格

| 组件 | 规格 |
|------|------|
| SoC | Qualcomm IPQ6010 (4×Cortex-A53 @ 1.8GHz) |
| 内存 | 512MB DDR4 |
| 存储 | eMMC (mmcblk0) |
| 网络 | 1×2.5G WAN + 4×1G LAN |
| WiFi | 2×2 MU-MIMO 2.4GHz + 4×4 MU-MIMO 5GHz (ath11k) |

### 软件版本

| 组件 | 版本 |
|------|------|
| 内核 | Linux 6.6.22 LTS |
| 系统 | Alpine Linux 3.19 |
| 架构 | ARM64 (aarch64) |
| 初始化 | OpenRC |

---

## ✨ 功能特性

### 已实现功能 (17项)

| 功能 | 命令/服务 | 状态 |
|------|----------|------|
| **基础功能** | | |
| LED 指示灯 | `/etc/init.d/leds` | ✅ |
| 恢复出厂 | `factory-reset` | ✅ |
| 按钮控制 | `/etc/init.d/buttons` | ✅ |
| **网络功能** | | |
| WiFi 管理 | `wifi setup/up/down` | ✅ |
| 端口转发 | `port-forward add/del/list` | ✅ |
| 固件升级 | `sysupgrade <固件>` | ✅ |
| PPPoE 拨号 | `pppoe-setup config` | ✅ |
| **系统管理** | | |
| Web 管理界面 | http://192.168.1.1 | ✅ |
| IPv6 支持 | `/etc/init.d/ipv6` | ✅ |
| QoS 流量控制 | `qos set <下载> <上传>` | ✅ |
| UPnP | `/etc/init.d/upnp` | ✅ |
| **安全功能** | | |
| VPN 客户端 | `vpn-setup openvpn/wireguard` | ✅ |
| 访客网络 | `/etc/init.d/guest-network` | ✅ |
| MAC 过滤 | `mac-filter add/del` | ✅ |
| **进阶功能** | | |
| USB 存储 | `/etc/init.d/usb` | ✅ |
| 网络监控 | `network-monitor start/report` | ✅ |
| 定时任务 | cron | ✅ |

---

## 🚀 快速开始

### 方式一：GitHub Actions 自动构建

1. Fork 本仓库
2. 推送代码触发构建
3. 从 Releases 下载固件

### 方式二：本地构建

```bash
# 安装依赖
sudo apt-get install build-essential flex bison gcc-aarch64-linux-gnu

# 克隆项目
git clone https://github.com/zhhhn/ax6600-alpine.git
cd ax6600-alpine

# 构建固件
./build.sh

# 输出文件
ls -lh out/
# ax6600-alpine-factory.bin  - 完整刷机包 (~46MB)
# ax6600-alpine.itb          - FIT 镜像 (~14MB)
# alpine-rootfs.tar.gz       - rootfs (~33MB)
# modules.tar.gz             - 内核模块 (~69MB)
```

---

## 📱 固件刷写

### 方式一：U-Boot TFTP

```bash
# 在 U-Boot 控制台执行
setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10
tftpboot 0x44000000 ax6600-alpine-factory.bin
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000
reset
```

### 方式二：U-Boot Web UI

1. 按住 Reset 键上电
2. 访问 http://192.168.1.1
3. 上传固件

---

## ⚙️ 默认配置

| 项目 | 设置 |
|------|------|
| LAN IP | 192.168.1.1 |
| WAN | DHCP 自动获取 |
| SSH | `ssh root@192.168.1.1` |
| Web UI | http://192.168.1.1 |
| WiFi 2.4G | AX6600 / admin123 |
| WiFi 5G | AX6600-5G / admin123 |

---

## 📁 项目结构

```
ax6600-alpine/
├── .github/workflows/    # GitHub Actions
├── configs/              # 设备树配置
├── rootfs-overlay/       # 文件系统覆盖
│   ├── etc/              # 配置文件
│   ├── usr/sbin/         # 管理脚本
│   └── www/              # Web UI
├── scripts/              # 构建和测试脚本
├── build.sh              # 主构建脚本
├── README.md             # 本文档
└── DEVELOPMENT.md        # 开发文档
```

---

## 🔧 常用命令

```bash
# WiFi 管理
wifi setup MySSID MyPassword
wifi status

# 端口转发
port-forward add 8080 192.168.1.100 80
port-forward list

# QoS
qos set 100 50

# 恢复出厂
factory-reset

# 网络监控
network-monitor start
network-monitor report 24
```

---

## 🧪 测试

### 本地测试

```bash
# 运行所有测试
./scripts/test-firmware.sh all

# 快速冒烟测试
./scripts/test-firmware.sh smoke
```

### 模拟器测试

```bash
# 启动 Python 模拟器
python3 scripts/simulate.py
# 访问 http://localhost:8080
```

---

## 📖 文档

- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南、功能列表、测试方法

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## ⚠️ 免责声明

- 刷机有风险，可能导致设备变砖
- 刷机将失去官方保修
- 请备份 ART 分区（WiFi 校准数据）
- 作者不对任何损失负责

---

**Made with ⚡ by router enthusiasts**