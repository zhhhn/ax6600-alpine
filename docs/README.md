# JDCloud AX6600 Alpine Linux 路由器固件

> 企业级路由器固件，基于 Alpine Linux，实现 OpenWrt 同等功能

---

## 项目简介

将完整的 Alpine Linux 系统移植到京东云 AX6600 路由器，提供类似 OpenWrt 的功能和体验。

### 核心特性

- **完整 Linux 系统** — Alpine Linux 3.19 + Linux 6.6.22 LTS
- **Web 管理界面** — ClawUI，类似 LuCI 的现代化界面
- **45 个应用** — 覆盖网络、代理、存储、媒体等领域
- **APK 包管理** — 直接使用 Alpine 软件仓库

---

## 硬件支持

| 设备 | 芯片 | 内存 | 网络 | 状态 |
|------|------|------|------|------|
| 京东云 AX6600 | IPQ6010 (4×A53@1.8GHz) | 512MB | 1×2.5G + 4×1G | ✅ 支持 |

硬件规格：
```
SoC:     Qualcomm IPQ6010
CPU:     4× Cortex-A53 @ 1.8GHz
内存:    512MB DDR4
WiFi:    2×2 MU-MIMO 2.4GHz + 4×4 MU-MIMO 5GHz (ath11k)
网络:    1×2.5G WAN + 4×1G LAN
```

---

## 固件下载

从 [GitHub Releases](https://github.com/zhhhn/ax6600-alpine/releases) 下载：

| 文件 | 大小 | 说明 |
|------|------|------|
| `factory.bin` | 46MB | 完整刷机包 |
| `rootfs.tar.gz` | 33MB | 根文件系统 |
| `modules.tar.gz` | 69MB | 内核模块 |

---

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/zhhhn/ax6600-alpine.git
cd ax6600-alpine

# 本地构建
./build.sh

# 输出文件
ls -lh out/
```

刷机后访问：
```
Web UI:  http://192.168.1.1
SSH:     ssh root@192.168.1.1
WiFi:    AX6600 / admin123
```

---

## 功能列表

### 系统功能 (17项)

| 功能 | CLI 命令 | Web UI |
|------|----------|--------|
| WiFi 管理 | `wifi setup/up/down` | ✅ |
| 网络配置 | `/etc/network/interfaces` | ✅ |
| PPPoE 拨号 | `pppoe-setup` | ✅ |
| 端口转发 | `port-forward` | ✅ |
| QoS 流控 | `qos set` | ✅ |
| 多线负载 | `/etc/init.d/multiwan` | ✅ |
| 防火墙 | nftables | ✅ |
| VPN 客户端 | `vpn-setup` | ✅ |

### 应用生态 (45个)

| 分类 | 数量 | 代表应用 |
|------|------|----------|
| 网络管理 | 8 | PPPoE, DDNS, QoS, 端口转发 |
| 代理工具 | 10 | Xray, Clash, Hysteria2, HomeProxy |
| 存储服务 | 5 | Samba, FTP, Syncthing |
| 下载工具 | 4 | Aria2, Transmission, qBittorrent |
| 媒体服务 | 3 | Jellyfin, MiniDLNA |
| 系统工具 | 8 | Docker, Nginx, AdGuard, Pi-hole |
| IoT/其他 | 5 | MQTT, Gitea, 备份恢复 |

---

## 项目状态

| 阶段 | 状态 | 完成度 |
|------|------|--------|
| CI 构建 | ✅ 完成 | 100% |
| 内核编译 | ✅ 完成 | 100% |
| 功能开发 | ✅ 完成 | 100% |
| 应用生态 | ✅ 完成 | 100% (45应用) |
| 文档整理 | ✅ 完成 | 100% |
| 真机测试 | ⏳ 待进行 | 0% |

---

## 文档目录

| 文档 | 说明 |
|------|------|
| [GUIDE.md](docs/GUIDE.md) | 使用指南（构建+刷机） |
| [DEVELOPMENT.md](docs/DEVELOPMENT.md) | 开发指南（开发+测试+CI） |
| [APPS.md](docs/APPS.md) | 45个应用详细列表 |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | 系统架构设计 |
| [STATUS.md](docs/STATUS.md) | 项目状态报告 |
| [CHANGELOG.md](docs/CHANGELOG.md) | 变更日志 |

---

## 项目结构

```
ax6600-alpine/
├── configs/           # 设备树配置
├── scripts/           # 构建脚本
├── rootfs-overlay/    # 文件系统覆盖层
├── clawui/            # Web 管理系统
│   └── apps/          # 45个应用
├── docs/              # 文档
├── build.sh           # 主构建入口
└── README.md          # 本文档
```

---

## 免责声明

- **刷机有风险**，可能导致设备变砖
- **失去保修**，刷机后不再享受官方保修
- **备份 ART**，请备份 WiFi 校准数据分区
- **作者不对任何损失负责**

---

## 许可证

- 内核代码: GPL v2
- Alpine Linux: MIT
- 构建脚本: MIT
- ClawUI: MIT

---

**Made with ⚡ by router enthusiasts**