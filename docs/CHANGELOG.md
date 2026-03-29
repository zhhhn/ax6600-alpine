# 变更日志

> 记录项目重要变更

---

## [v1.0.0-beta] - 2026-03-29

### 新增功能

#### 系统核心 (17项)
- WiFi 管理 - 2.4GHz/5GHz 双频配置
- 网络配置 - LAN/WAN/PPPoE
- DHCP 服务 - dnsmasq 集成
- DNS 解析 - 支持自定义 DNS
- 防火墙 - nftables 规则管理
- 端口转发 - NAT 规则配置
- UPnP - 自动端口映射
- IPv6 支持 - NAT64/DNS64
- QoS 流量控制 - tc 流量整形
- 多线负载均衡 - 多 WAN 故障切换
- 静态路由 - 策略路由支持
- VPN 客户端 - WireGuard/OpenVPN
- 访客网络 - 独立 SSID/VLAN
- 网络监控 - 实时流量统计
- 固件升级 - sysupgrade
- 恢复出厂 - factory-reset
- LED/按钮控制 - GPIO 管理

#### ClawUI 应用 (45个)

| 分类 | 应用 |
|------|------|
| 网络管理 | PPPoE, 端口转发, DDNS, 静态路由, 多线负载, QoS, 流量监控, 网络诊断 |
| 代理工具 | Xray, Trojan, Clash, Hysteria2, SOCKS5, Shadowsocks, WireGuard, OpenVPN, Tailscale, ZeroTier, HomeProxy |
| 存储服务 | Samba, FTP, File Browser, Syncthing, Transmission |
| 下载工具 | Aria2, Transmission, qBittorrent, FRP |
| 媒体服务 | Jellyfin, MiniDLNA, PhotoPrism |
| 系统工具 | Docker, Nginx, AdGuard, Pi-hole, KMS, 网速测试, 网络唤醒, Uptime Kuma |
| IoT/其他 | MQTT, Gitea, Memos, Tiny Tiny RSS, 备份恢复, NPS, NPC |

### 技术实现
- Alpine Linux 3.19 基础系统
- Linux 6.6.22 LTS 内核
- GitHub Actions CI/CD
- RESTful API 设计

---

## 开发历程

### 阶段1: 硬件准备 (2026-03-27)

**硬件信息分析**:
- SoC: Qualcomm IPQ6010 (4×Cortex-A53 @ 1.8GHz)
- WiFi: QCN5022 (2.4G) + QCN5052 (5G)
- 存储: 64GB eMMC
- 内存: 512MB DDR4

**关键发现**:
- IPQ6018 设备树已 upstream
- ath11k WiFi 驱动已支持 IPQ6018
- OpenWrt 使用 FIT 镜像格式

**分区布局**:
```
mmcblk0p11  HLOS      6MB    内核分区
mmcblk0p18  rootfs    512MB+ 根文件系统
mmcblk0p27  storage   剩余   数据分区
```

### 阶段2: 启动环境分析 (2026-03-27)

- 分析 U-Boot 启动流程
- 研究网络引导 (TFTP)
- 准备 Alpine 内核和 initramfs

**内核配置要点**:
```
CONFIG_ARCH_QCOM=y
CONFIG_ARCH_IPQ=y
CONFIG_SERIAL_MSM_GENI=y
CONFIG_MMC_SDHCI_MSM=y
CONFIG_ATH11K_AHB=y
```

### 阶段3: 内核编译 (2026-03-28)

- 下载 Linux 6.6.22 源码
- 应用 IPQ60xx 补丁
- 编译内核镜像和模块
- 创建设备树 (ipq6018-jdcloud-ax6600.dts)

**解决的问题**:
- `.gitignore` 排除脚本规则
- DTB 文件缺失
- CORESIGHT 模块编译失败
- Release 权限 403

### 阶段4: 根文件系统 (2026-03-28~29)

- 构建 Alpine rootfs
- 配置 OpenRC 服务
- 开发 17 项路由功能
- 实现 ClawUI 基础框架

### 阶段5: 应用开发 (2026-03-29)

- 开发 12 个基础网络应用
- 开发 24 个扩展应用
- 开发 6 个代理应用
- 开发 Hysteria2 + HomeProxy

### 阶段6: 文档整理 (2026-03-29)

- 统一中文文档
- 集中存放 docs/ 目录
- 去除重复说明
- 修复构建脚本问题

---

## 版本规划

### v1.0.0 (计划)
- 真机刷机验证
- WiFi 驱动确认
- 性能测试报告

### v1.1.0 (未来)
- Vue.js 前端重构
- 多语言支持 (i18n)
- 更多代理协议

---

**格式遵循**: [Keep a Changelog](https://keepachangelog.com/)