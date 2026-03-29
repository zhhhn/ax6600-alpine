# 项目架构

本文档描述 AX6600 Alpine Linux 路由器固件的整体架构设计。

## 系统架构

```
┌────────────────────────────────────────────────────────────────────┐
│                         用户层                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │ Web UI   │  │ SSH      │  │ 串口     │  │ 命令行   │           │
│  │ ClawUI   │  │ Dropbear │  │ UART     │  │ BusyBox  │           │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘           │
├───────┴────────────┴────────────┴────────────┴──────────────────────┤
│                         服务层                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │ network  │  │ wifi     │  │ firewall │  │ dnsmasq  │           │
│  │ 网络服务 │  │ 无线服务 │  │ 防火墙   │  │ DHCP/DNS │           │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │ clawui   │  │ qos      │  │ upnp     │  │ usb      │           │
│  │ Web服务  │  │ 流量控制 │  │ UPnP     │  │ USB挂载  │           │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
├─────────────────────────────────────────────────────────────────────┤
│                         核心层                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │ OpenRC   │  │ nftables │  │ wpa_*/hostapd│  │ APK      │           │
│  │ 初始化   │  │ 包过滤   │  │ 无线驱动 │  │ 包管理   │           │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
├─────────────────────────────────────────────────────────────────────┤
│                         内核层                                      │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │ Linux 6.6.22 LTS (aarch64)                               │     │
│  │ 驱动: ath11k (WiFi) | qcom-emac (以太网) | sdhci (eMMC)  │     │
│  └──────────────────────────────────────────────────────────┘     │
├─────────────────────────────────────────────────────────────────────┤
│                         硬件层                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │ IPQ6010  │  │ QCN5022  │  │ QCN5052  │  │ eMMC     │           │
│  │ SoC      │  │ 2.4GHz   │  │ 5GHz     │  │ 存储     │           │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

## 目录结构

```
ax6600-alpine/
│
├── .github/
│   └── workflows/
│       └── build.yml              # GitHub Actions CI/CD
│
├── configs/
│   └── ipq6018-jdcloud-ax6600.dts # 设备树源文件
│
├── scripts/                       # 构建和工具脚本
│   ├── build-kernel.sh            # 内核编译
│   ├── build-rootfs.sh            # 根文件系统构建
│   ├── package-firmware.sh        # 固件打包
│   ├── test-firmware.sh           # 测试框架
│   ├── vm.sh                      # QEMU 虚拟机
│   ├── router-sim.sh              # Docker 模拟器
│   ├── simulate.py                # Python 模拟器
│   └── docker-test.sh             # Docker 测试
│
├── rootfs-overlay/                # 文件系统覆盖层
│   │
│   ├── etc/                       # 配置文件
│   │   ├── init.d/                # OpenRC 服务脚本
│   │   │   ├── leds               #   LED 指示灯
│   │   │   ├── buttons            #   按钮控制
│   │   │   ├── network            #   网络服务
│   │   │   ├── wifi               #   WiFi 服务
│   │   │   ├── firewall           #   防火墙
│   │   │   ├── dnsmasq            #   DHCP/DNS
│   │   │   ├── ipv6               #   IPv6
│   │   │   ├── upnp               #   UPnP
│   │   │   ├── guest-network      #   访客网络
│   │   │   ├── mac-filter         #   MAC 过滤
│   │   │   ├── qos                #   QoS
│   │   │   ├── usb                #   USB 支持
│   │   │   └── clawui             #   Web UI
│   │   │
│   │   ├── hostapd/               # WiFi 配置
│   │   │   ├── hostapd.conf       #   2.4GHz
│   │   │   └── hostapd-5g.conf    #   5GHz
│   │   │
│   │   ├── network/
│   │   │   └── interfaces         # 网络接口配置
│   │   │
│   │   ├── clawui/                # ClawUI 配置
│   │   │   ├── config             #   主配置
│   │   │   └── httpd.conf         #   HTTP 服务器配置
│   │   │
│   │   ├── nftables.conf          # 防火墙规则
│   │   ├── dnsmasq.conf           # DHCP/DNS 配置
│   │   └── shadow                 # 用户密码
│   │
│   ├── usr/
│   │   ├── sbin/                  # 管理工具
│   │   │   ├── wifi               #   WiFi 管理
│   │   │   ├── port-forward       #   端口转发
│   │   │   ├── qos                #   流量控制
│   │   │   ├── factory-reset      #   恢复出厂
│   │   │   ├── pppoe-setup        #   PPPoE
│   │   │   ├── sysupgrade         #   固件升级
│   │   │   ├── vpn-setup          #   VPN 配置
│   │   │   ├── mac-filter         #   MAC 过滤
│   │   │   ├── network-monitor    #   网络监控
│   │   │   └── clawui             #   Web UI 服务
│   │   │
│   │   └── share/
│   │       └── clawui/            # ClawUI 应用
│   │           ├── www/           #   Web 前端
│   │           │   ├── index.html
│   │           │   ├── css/
│   │           │   ├── js/
│   │           │   └── cgi-bin/
│   │           └── api/           #   REST API
│   │               ├── status.sh
│   │               ├── network.sh
│   │               ├── wireless.sh
│   │               ├── firewall.sh
│   │               ├── packages.sh
│   │               ├── system.sh
│   │               ├── dhcp.sh
│   │               ├── qos.sh
│   │               ├── vpn.sh
│   │               └── apps.sh
│   │
│   └── www/ -> usr/share/clawui/www/  # 符号链接
│
├── clawui/                        # ClawUI 源码和开发
│   ├── www/                       # 前端代码
│   ├── api/                       # API 脚本
│   ├── apps/                      # 可选应用
│   │   └── wireguard/             #   示例应用
│   ├── tools/                     # 开发工具
│   └── build-apps.sh              # 应用构建
│
├── docs/                          # 文档
│   ├── ARCHITECTURE.md            # 架构文档 (本文件)
│   ├── BUILD.md                   # 构建指南
│   ├── FLASHING.md                # 刷机指南
│   ├── CLAWUI.md                  # Web 界面文档
│   ├── APPS.md                    # 应用生态
│   ├── TESTING.md                 # 测试文档
│   └── DEVELOPMENT.md             # 开发指南
│
├── build.sh                       # 主构建入口
├── README.md                      # 项目入口文档
└── LICENSE                        # 许可证
```

## 核心组件

### 1. 构建系统

| 脚本 | 功能 | 输入 | 输出 |
|------|------|------|------|
| `build-kernel.sh` | 编译 Linux 内核 | configs/*.dts | Image.gz, *.dtb |
| `build-rootfs.sh` | 构建 Alpine 根文件系统 | rootfs-overlay/ | rootfs.tar.gz |
| `package-firmware.sh` | 打包固件 | kernel + rootfs | factory.bin |

### 2. 服务系统

使用 OpenRC 初始化系统：

```
系统启动
    │
    ├── bootmisc      # 基础系统初始化
    │
    ├── network       # 网络接口
    │       │
    │       ├── firewall  # 防火墙规则
    │       └── dnsmasq   # DHCP/DNS
    │
    ├── wifi          # WiFi 服务
    │       └── hostapd
    │
    └── clawui        # Web UI
            └── httpd
```

### 3. Web 界面 (ClawUI)

```
ClawUI 架构
    │
    ├── 前端 (www/)
    │   ├── HTML 页面
    │   ├── CSS 样式
    │   └── JavaScript 应用
    │
    ├── 后端 API (api/)
    │   ├── Shell CGI 脚本
    │   └── REST 端点
    │
    └── 应用系统 (apps/)
        ├── 应用注册表
        └── 可选应用
```

### 4. 命令行工具

```
/usr/sbin/
    │
    ├── wifi              # WiFi 管理
    │   ├── setup         # 配置 SSID/密码
    │   ├── up/down       # 启停
    │   ├── status        # 状态
    │   └── scan          # 扫描
    │
    ├── port-forward      # 端口转发
    │   ├── add           # 添加规则
    │   ├── del           # 删除规则
    │   └── list          # 列出规则
    │
    ├── qos               # 流量控制
    │   ├── set           # 设置带宽
    │   ├── limit         # IP 限速
    │   └── status        # 状态
    │
    ├── factory-reset     # 恢复出厂
    │
    ├── sysupgrade        # 固件升级
    │   ├── <file>        # 升级固件
    │   ├── -b            # 备份配置
    │   └── -r            # 恢复配置
    │
    └── vpn-setup         # VPN 配置
        ├── openvpn       # OpenVPN
        └── wireguard     # WireGuard
```

## 数据流

### 启动流程

```
U-Boot 加载
    │
    ├── 加载 ITB 文件
    │       ├── Image.gz (内核)
    │       ├── DTB (设备树)
    │       └── initramfs
    │
    ├── 内核初始化
    │       └── 驱动加载 (ath11k, emac, sdhci)
    │
    ├── 挂载 rootfs
    │       └── mmcblk0p18 (ext4)
    │
    └── OpenRC 启动
            ├── 网络服务
            ├── WiFi 服务
            └── Web UI
```

### 网络数据流

```
外网 (WAN)
    │
    │  eth0 (2.5G)
    ▼
┌─────────────┐
│  防火墙      │  nftables
│  NAT        │
└─────────────┘
    │
    │  br-lan
    ▼
┌─────────────┐
│  DHCP/DNS   │  dnsmasq
└─────────────┘
    │
    ├── eth1-4 (LAN 口)
    │
    └── wlan0/1 (WiFi)
```

### Web 请求流程

```
浏览器请求
    │
    │  HTTP :80
    ▼
┌─────────────┐
│  httpd      │  busybox httpd
└─────────────┘
    │
    │  CGI 调用
    ▼
┌─────────────┐
│  api/*.sh   │  Shell 脚本
└─────────────┘
    │
    │  系统调用
    ▼
┌─────────────┐
│  系统命令   │  ip, iw, nft 等
└─────────────┘
```

## 存储布局

```
eMMC (mmcblk0)
    │
    ├── mmcblk0p11   HLOS (内核)     6MB
    │
    ├── mmcblk0p18   rootfs         512MB+
    │       ├── /bin
    │       ├── /etc
    │       ├── /lib
    │       ├── /usr
    │       └── /var
    │
    └── mmcblk0p27   数据分区       剩余空间
```

## 配置系统

配置文件分布：

| 配置 | 路径 | 格式 |
|------|------|------|
| 网络接口 | /etc/network/interfaces | Debian 格式 |
| WiFi | /etc/hostapd/*.conf | hostapd 格式 |
| DHCP/DNS | /etc/dnsmasq.conf | dnsmasq 格式 |
| 防火墙 | /etc/nftables.conf | nft 格式 |
| Web UI | /etc/clawui/config | KEY=VALUE |
| 服务启用 | /etc/runlevels/default/ | OpenRC 符号链接 |

## 扩展机制

### 添加新服务

1. 创建 init 脚本:
```bash
#!/sbin/openrc-run
name="myservice"
command="/usr/bin/myservice"
depend() { need net; }
```

2. 启用服务:
```bash
rc-update add myservice default
```

### 添加 Web UI 应用

1. 创建应用目录:
```bash
mkdir -p /usr/share/clawui/apps/myapp/api
```

2. 添加 API:
```bash
#!/bin/sh
echo "Content-Type: application/json"
echo ""
echo '{"status": "ok"}'
```

3. 注册应用到 `/usr/share/clawui/apps/registry.json`

## 性能特性

| 指标 | 数值 |
|------|------|
| 启动时间 | ~30 秒 |
| 内存占用 | ~80MB (空闲) |
| 固件大小 | ~46MB |
| CPU 占用 | <5% (空闲) |

---

相关文档：
- [BUILD.md](BUILD.md) - 构建指南
- [CLAWUI.md](CLAWUI.md) - Web 界面
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南