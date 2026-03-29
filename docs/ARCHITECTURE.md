# 系统架构

> AX6600 Alpine Linux 路由器固件架构设计

---

## 系统分层

```
┌────────────────────────────────────────────────────┐
│                    用户层                          │
│  Web UI (ClawUI)  │  SSH  │  串口  │  命令行      │
├────────────────────────────────────────────────────┤
│                    服务层                          │
│  network │ wifi │ firewall │ dnsmasq │ clawui     │
├────────────────────────────────────────────────────┤
│                    核心层                          │
│  OpenRC  │  nftables  │  wpa/hostapd  │  APK     │
├────────────────────────────────────────────────────┤
│                    内核层                          │
│  Linux 6.6.22 LTS (aarch64)                        │
│  ath11k │ qcom-emac │ sdhci                        │
├────────────────────────────────────────────────────┤
│                    硬件层                          │
│  IPQ6010 │ QCN5022/5052 │ eMMC                    │
└────────────────────────────────────────────────────┘
```

---

## 目录结构

```
ax6600-alpine/
├── configs/              # 设备树配置
│   └── ipq6018-jdcloud-ax6600.dts
│
├── scripts/              # 构建脚本
│   ├── build-kernel.sh
│   ├── build-rootfs.sh
│   ├── package-firmware.sh
│   └── test-firmware.sh
│
├── rootfs-overlay/       # 文件系统覆盖层
│   ├── etc/
│   │   ├── init.d/       # OpenRC 服务
│   │   ├── hostapd/      # WiFi 配置
│   │   ├── network/      # 网络配置
│   │   └── clawui/       # Web UI 配置
│   └── usr/sbin/         # 管理命令
│
├── clawui/               # Web 管理系统
│   ├── apps/             # 45个应用
│   └── build-apps.sh
│
└── docs/                 # 文档
```

---

## 核心组件

### 服务系统

使用 OpenRC 初始化系统：

```
系统启动
├── bootmisc      # 基础初始化
├── network       # 网络接口
│   ├── firewall
│   └── dnsmasq
├── wifi          # WiFi 服务
│   └── hostapd
└── clawui        # Web UI
```

### 命令行工具

```
/usr/sbin/
├── wifi          # WiFi 管理
├── port-forward  # 端口转发
├── qos           # 流量控制
├── factory-reset # 恢复出厂
├── sysupgrade    # 固件升级
└── vpn-setup     # VPN 配置
```

### Web 界面

```
ClawUI 架构
├── 前端 (www/)
│   └── HTML/CSS/JS
├── 后端 API (api/)
│   └── Shell CGI
└── 应用系统 (apps/)
    └── 45个可选应用
```

---

## 网络数据流

```
外网 (WAN) → eth0 (2.5G)
    ↓
防火墙 (nftables) + NAT
    ↓
br-lan
├── eth1-4 (LAN)
└── wlan0/1 (WiFi)
```

---

## 存储布局

```
eMMC (mmcblk0)
├── mmcblk0p11  内核分区    6MB
├── mmcblk0p18  rootfs     512MB+
└── mmcblk0p27  数据分区    剩余空间
```

---

## 配置文件

| 配置 | 路径 |
|------|------|
| 网络接口 | `/etc/network/interfaces` |
| WiFi | `/etc/hostapd/*.conf` |
| DHCP/DNS | `/etc/dnsmasq.conf` |
| 防火墙 | `/etc/nftables.conf` |
| Web UI | `/etc/clawui/config` |

---

## 性能指标

| 指标 | 数值 |
|------|------|
| 启动时间 | ~30 秒 |
| 内存占用 | ~80MB (空闲) |
| 固件大小 | ~46MB |
| CPU 占用 | <5% (空闲) |

---

相关文档：
- [GUIDE.md](GUIDE.md) - 使用指南
- [APPS.md](APPS.md) - 应用列表
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南