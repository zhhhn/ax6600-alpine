# JDCloud AX6600 Alpine Linux

> 将完整Alpine Linux移植到京东云AX6600路由器

[![Build Status](https://github.com/YOUR_USERNAME/ax6600-alpine/workflows/Build/badge.svg)](https://github.com/YOUR_USERNAME/ax6600-alpine/actions)

---

## 概述

基于OpenWrt源码，将Alpine Linux移植到京东云AX6600 (Athena)路由器。

### 硬件规格

- **SoC**: Qualcomm IPQ6010 (4×Cortex-A53 @ 1.8GHz)
- **WiFi**: QCN5022 (2.4G) + QCN5052 (5G) + QCN9074 (5G PCIe)
- **以太网**: 1×2.5G WAN + 4×1G LAN
- **存储**: 64GB eMMC
- **内存**: 512MB DDR3 (可硬改2GB)

### 软件版本

- **内核**: Linux 6.6.22 LTS
- **根系统**: Alpine Linux 3.19
- **架构**: ARM64 (aarch64)
- **初始化**: OpenRC

---

## 快速开始

### 方式1 - GitHub Actions自动构建（推荐）

1. **Fork本仓库**到您的GitHub账号
2. **推送代码**触发自动构建
3. **下载固件**从Releases页面获取

### 方式2 - 本地构建

```bash
# 安装依赖
sudo apt-get install build-essential flex bison gcc-aarch64-linux-gnu

# 克隆项目
git clone https://github.com/YOUR_USERNAME/ax6600-alpine.git
cd ax6600-alpine

# 构建固件
./build.sh

# 输出文件在 out/ 目录
ls -lh out/
```

---

## 固件刷写

### U-Boot TFTP方式

```bash
# 在路由器U-Boot控制台执行
setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10
tftpboot 0x44000000 ax6600-alpine-factory.bin
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000
reset
```

### U-Boot Web UI方式

1. 按住reset键上电
2. 蓝灯亮起后访问 http://192.168.1.1
3. 上传固件文件

详细刷机指南见 [INSTALL.md](INSTALL.md)

---

## 默认配置

| 项目 | 设置 |
|------|------|
| LAN IP | 192.168.1.1 |
| WAN | DHCP自动获取 |
| SSH | root (首次登录设置密码) |
| WiFi 2.4G | AX6600-2.4G / 12345678 |
| WiFi 5G | AX6600-5G / 12345678 |

---

## 项目结构

```
ax6600-alpine/
├── .github/workflows/     # GitHub Actions配置
├── configs/               # 设备树配置
│   └── ipq6018-jdcloud-ax6600.dts
├── rootfs-overlay/        # rootfs自定义文件
│   ├── etc/
│   │   ├── dnsmasq.conf
│   │   ├── network/interfaces
│   │   ├── nftables.conf
│   │   └── ...
├── scripts/               # 构建脚本
│   ├── build-kernel.sh
│   ├── build-rootfs.sh
│   └── package-firmware.sh
├── build.sh               # 主构建脚本
└── docs/                  # 文档
    ├── INSTALL.md
    ├── MANIFEST.md
    └── GITHUB_SETUP.md
```

---

## 功能特性

- ✅ **网络**: WAN (DHCP), LAN (桥接), NAT转发
- ✅ **DHCP/DNS**: dnsmasq服务
- ✅ **防火墙**: nftables规则
- ✅ **WiFi**: hostapd (2.4G + 5G)
- ✅ **SSH**: dropbear服务器
- ✅ **包管理**: Alpine APK
- ⚠️ **NSS加速**: 需要额外开发

---

## 分区布局

```
/dev/mmcblk0 (64GB eMMC)
├── p16 (0:HLOS)    6MB  - 内核 (FIT镜像)
├── p18 (rootfs)   512MB+ - Alpine rootfs
└── p27 (storage)  ~55GB - 数据存储
```

---

## 开发文档

- [安装指南](INSTALL.md) - 详细刷机步骤
- [固件清单](MANIFEST.md) - 固件组件说明
- [GitHub设置](GITHUB_SETUP.md) - CI/CD配置
- [生产构建](PRODUCTION_BUILD.md) - 完整构建指南

---

## 贡献

欢迎提交Issue和Pull Request！

---

## 许可证

- 内核: GPL v2
- Alpine Linux: MIT
- 构建脚本: MIT

---

## 免责声明

⚠️ **刷机有风险，操作需谨慎！**

- 刷机可能导致设备变砖
- 刷机将失去官方保修
- 请备份ART分区（WiFi校准数据）
- 作者不对刷机造成的损失负责

---

**Made with ⚡ by router enthusiasts**
