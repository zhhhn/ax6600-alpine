# JDCloud AX6600 Alpine Linux 开发文档

## 项目目标

将完整的 Alpine Linux 系统移植到京东云 AX6600 路由器，实现 OpenWrt 的所有核心功能。

---

## 功能开发计划

### Phase 1: 基础功能完善 (P0)

#### 1.1 LED 指示灯控制

**目标：** 实现电源灯、系统状态灯、WiFi 状态灯的控制

**设备 GPIO 映射（需确认）：**
```
LED_GREEN_POWER   - 电源指示灯
LED_BLUE_SYSTEM   - 系统状态灯  
LED_WIFI_2G       - 2.4GHz WiFi 状态
LED_WIFI_5G       - 5GHz WiFi 状态
```

**实现方案：**
1. 在设备树中定义 LED GPIO
2. 创建 `/etc/init.d/leds` 服务脚本
3. 实现状态指示逻辑

**代码位置：**
- `configs/ipq6018-jdcloud-ax6600.dts` - 设备树 LED 定义
- `rootfs-overlay/etc/init.d/leds` - LED 控制服务

**状态：** ⏳ 待开发

---

#### 1.2 恢复出厂设置

**目标：** 实现一键恢复出厂配置

**实现方案：**
1. 保留一份默认配置在 `/etc/config-default/`
2. 创建 `/usr/sbin/factory-reset` 脚本
3. 绑定 Reset 按钮（需要设备树支持）

**脚本逻辑：**
```bash
#!/bin/sh
# factory-reset
cp -r /etc/config-default/* /etc/
rm -f /etc/shadow
echo "root:::0:::::" > /etc/shadow
reboot
```

**代码位置：**
- `rootfs-overlay/usr/sbin/factory-reset`
- `rootfs-overlay/etc/config-default/` - 默认配置备份

**状态：** ⏳ 待开发

---

#### 1.3 按钮控制

**目标：** 实现 Reset 按钮、WPS 按钮的功能

**实现方案：**
1. 设备树定义 GPIO 按钮
2. 使用 `gpio-keys` 驱动
3. 创建按钮事件监听脚本

**按钮映射（需确认）：**
```
BTN_RESET  - 恢复出厂（长按 10 秒）
BTN_WPS    - WPS 连接（短按）
```

**代码位置：**
- `configs/ipq6018-jdcloud-ax6600.dts` - 按钮定义
- `rootfs-overlay/etc/init.d/buttons` - 按钮服务

**状态：** ⏳ 待开发

---

### Phase 2: 网络功能增强 (P1)

#### 2.1 WiFi 配置脚本

**目标：** 提供简单的 WiFi 配置工具

**实现方案：**
创建类似 OpenWrt `wifi` 命令的配置脚本

**命令设计：**
```bash
wifi setup <ssid> <password>       # 配置 WiFi
wifi up                            # 启动 WiFi
wifi down                          # 关闭 WiFi
wifi status                        # 显示状态
wifi scan                          # 扫描网络
```

**代码位置：**
- `rootfs-overlay/usr/sbin/wifi`

**状态：** ⏳ 待开发

---

#### 2.2 端口转发管理

**目标：** 提供端口转发配置工具

**实现方案：**
基于 nftables 实现端口转发规则管理

**命令设计：**
```bash
port-forward add <外部端口> <内网IP> <内网端口>
port-forward del <外部端口>
port-forward list
port-forward clear
```

**规则存储：** `/etc/port-forward.rules`

**代码位置：**
- `rootfs-overlay/usr/sbin/port-forward`
- `rootfs-overlay/etc/init.d/nat-rules`

**状态：** ⏳ 待开发

---

#### 2.3 固件升级脚本

**目标：** 实现类似 OpenWrt sysupgrade 的升级功能

**实现方案：**
1. 下载新固件到 /tmp
2. 验证 SHA256
3. 写入 mmcblk0 分区
4. 保留配置选项

**命令设计：**
```bash
sysupgrade <固件文件>              # 升级固件
sysupgrade -n <固件文件>           # 升级并清除配置
sysupgrade -b                     # 备份当前配置
sysupgrade -r                     # 恢复配置
```

**代码位置：**
- `rootfs-overlay/usr/sbin/sysupgrade`

**状态：** ⏳ 待开发

---

#### 2.4 PPPoE 拨号支持

**目标：** 支持国内宽带 PPPoE 拨号

**实现方案：**
1. 安装 `ppp` 包
2. 创建 PPPoE 配置模板
3. 提供 PPPoE 配置脚本

**命令设计：**
```bash
pppoe-setup <用户名> <密码>       # 配置 PPPoE
pppoe-connect                     # 连接
pppoe-disconnect                  # 断开
pppoe-status                      # 状态
```

**代码位置：**
- `rootfs-overlay/usr/sbin/pppoe-setup`
- `rootfs-overlay/etc/ppp/peers/dsl-provider`

**状态：** ⏳ 待开发

---

### Phase 3: 系统管理 (P2)

#### 3.1 Web 管理界面

**目标：** 提供简单的 Web 管理界面

**实现方案：**
使用 `lighttpd` + CGI 脚本实现轻量级 Web UI

**功能模块：**
- 状态概览（CPU、内存、网络流量）
- 网络配置（LAN/WAN/PPPoE）
- WiFi 配置（SSID、密码、信道）
- 端口转发
- 系统工具（重启、升级、备份）

**依赖包：**
```
lighttpd lighttpd-mod-cgi
```

**代码位置：**
- `rootfs-overlay/etc/lighttpd/`
- `rootfs-overlay/www/cgi-bin/`

**状态：** ⏳ 待开发

---

#### 3.2 IPv6 支持

**目标：** 完整的 IPv6 支持

**实现方案：**
1. 配置 IPv6 地址
2. 实现 IPv6 NAT66 或桥接模式
3. DHCPv6 服务器

**代码位置：**
- `rootfs-overlay/etc/network/interfaces.ipv6`
- `rootfs-overlay/etc/radvd.conf`

**状态：** ⏳ 待开发

---

#### 3.3 QoS/流量控制

**目标：** 实现简单的带宽控制

**实现方案：**
使用 tc (traffic control) 实现

**命令设计：**
```bash
qos-set <接口> <下载带宽> <上传带宽>
qos-clear
qos-status
```

**代码位置：**
- `rootfs-overlay/usr/sbin/qos`
- `rootfs-overlay/etc/init.d/qos`

**状态：** ⏳ 待开发

---

#### 3.4 UPnP 支持

**目标：** 支持自动端口映射

**实现方案：**
安装 `miniupnpd` 包

**配置：**
```
miniupnpd 配置指向 br-lan 和 eth0
```

**代码位置：**
- `rootfs-overlay/etc/miniupnpd.conf`
- `rootfs-overlay/etc/init.d/upnp`

**状态：** ⏳ 待开发

---

### Phase 4: 安全增强 (P3)

#### 4.1 VPN 客户端

**目标：** 支持 OpenVPN/WireGuard 客户端

**依赖包：**
```
openvpn 或 wireguard-tools
```

**状态：** ⏳ 待开发

---

#### 4.2 访客网络

**目标：** 提供隔离的访客 WiFi 网络

**实现方案：**
1. 创建独立的 VLAN
2. 独立的 SSID
3. 限制访客网络只能访问 WAN

**状态：** ⏳ 待开发

---

#### 4.3 MAC 过滤

**目标：** 支持黑/白名单 MAC 地址过滤

**实现方案：**
在 nftables 中添加 MAC 过滤规则

**状态：** ⏳ 待开发

---

### Phase 5: 进阶功能 (P4)

#### 5.1 USB 支持

**目标：** 支持 USB 存储共享

**依赖包：**
```
kmod-usb-storage usbutils ntfs-3g samba
```

**状态：** ⏳ 待开发

---

#### 5.2 定时任务

**目标：** 提供 Web UI 配置定时任务

**实现方案：**
基于 cron 实现

**状态：** ⏳ 待开发

---

#### 5.3 网络监控

**目标：** 实时流量监控和历史记录

**实现方案：**
使用 `vnstat` 或自定义脚本

**状态：** ⏳ 待开发

---

## 开发进度追踪

| Phase | 功能 | 状态 | 开始日期 | 完成日期 |
|-------|------|------|----------|----------|
| P0 | LED 控制 | ⏳ 待开发 | - | - |
| P0 | 恢复出厂 | ⏳ 待开发 | - | - |
| P0 | 按钮控制 | ⏳ 待开发 | - | - |
| P1 | WiFi 配置脚本 | ⏳ 待开发 | - | - |
| P1 | 端口转发 | ⏳ 待开发 | - | - |
| P1 | 固件升级 | ⏳ 待开发 | - | - |
| P1 | PPPoE | ⏳ 待开发 | - | - |
| P2 | Web UI | ⏳ 待开发 | - | - |
| P2 | IPv6 | ⏳ 待开发 | - | - |
| P2 | QoS | ⏳ 待开发 | - | - |
| P2 | UPnP | ⏳ 待开发 | - | - |
| P3 | VPN | ⏳ 待开发 | - | - |
| P3 | 访客网络 | ⏳ 待开发 | - | - |
| P3 | MAC 过滤 | ⏳ 待开发 | - | - |
| P4 | USB | ⏳ 待开发 | - | - |
| P4 | 定时任务 | ⏳ 待开发 | - | - |
| P4 | 网络监控 | ⏳ 待开发 | - | - |

---

## 设备信息参考

### 硬件规格

| 组件 | 规格 |
|------|------|
| SoC | Qualcomm IPQ6010 (4核 ARM Cortex-A53 @ 1.8GHz) |
| 内存 | 512MB DDR4 |
| 存储 | eMMC 128MB (mmcblk0) |
| 网络 | 1x 2.5G WAN (eth0) + 4x 1G LAN (eth1-4) |
| WiFi | 2x2 MU-MIMO 2.4GHz + 4x4 MU-MIMO 5GHz |
| WiFi 芯片 | Qualcomm QCN5022/QCN5052 (ath11k) |
| 分区 | mmcblk0p18 用于 rootfs |

### GPIO 引脚（需要实际测量确认）

| GPIO | 功能 | 备注 |
|------|------|------|
| GPIO_X | LED 绿灯（电源） | 待确认 |
| GPIO_Y | LED 蓝灯（系统） | 待确认 |
| GPIO_Z | Reset 按钮 | 待确认 |
| GPIO_W | WPS 按钮 | 待确认 |

---

## 开发环境

### 本地测试

```bash
# 在构建机器上测试脚本
bash scripts/build.sh

# 检查 rootfs 内容
ls -la build/alpine-rootfs/

# 测试服务脚本
bash rootfs-overlay/etc/init.d/network start
```

### 刷机测试

```bash
# 1. 连接 TTL 串口 (3.3V, 115200)
# 2. 进入 U-Boot
# 3. TFTP 传输固件
# 4. 写入 mmcblk0
```

---

## 文档更新日志

| 日期 | 更新内容 |
|------|----------|
| 2026-03-29 | 创建开发文档，规划所有功能 |

---

## 贡献指南

1. 每个功能开发完成后，更新状态为 ✅ 已完成
2. 记录开始和完成日期
3. 添加测试说明和注意事项
4. 更新 CHANGELOG.md

---

*本文档将随项目进展持续更新*