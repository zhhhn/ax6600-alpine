# ClawUI 应用生态系统

## 概述

ClawUI 应用系统解决了 Alpine 没有 LuCI 生态的问题，提供类似 OpenWrt 的应用包管理体验。

## 已开发应用 (12个)

### 网络管理类

| 应用 | ID | 功能 | 依赖 |
|------|-----|------|------|
| PPPoE | pppoe | 宽带拨号配置，支持诊断 | ppp, rp-pppoe |
| 端口转发 | portforward | 端口映射/DMZ/UPnP | nftables |
| 动态DNS | ddns | 阿里云/腾讯/Cloudflare DDNS | curl, ca-certificates |
| 静态路由 | routes | 静态路由/策略路由 | iproute2 |
| 多线负载 | multiwan | 多WAN负载均衡和故障切换 | iproute2, iptables |
| QoS控制 | qos | 流量整形和优先级队列 | iproute2, tc |
| 流量监控 | traffic | 实时流量统计和监控 | - |
| 网络诊断 | diag | Ping/Traceroute/DNS/端口扫描 | iputils, traceroute, nmap |

### VPN/穿透类

| 应用 | ID | 功能 | 依赖 |
|------|-----|------|------|
| WireGuard | wireguard | VPN管理和配置 | wireguard-tools |
| FRP穿透 | frp | FRP内网穿透客户端 | frp |

### 系统工具类

| 应用 | ID | 功能 | 依赖 |
|------|-----|------|------|
| 广告过滤 | adblock | DNS广告过滤，多规则源 | dnsmasq, curl |
| 备份恢复 | backup | 配置备份和恢复 | - |

### 内置应用 (核心功能)

| 应用 | 功能 |
|------|------|
| network | 网络设置 |
| wireless | 无线设置 |
| firewall | 防火墙 |
| dhcp | DHCP/DNS |
| system | 系统设置 |

## 应用结构

```
clawui-app-{name}/
├── APKBUILD              # Alpine 包定义
├── manifest.json         # 应用元数据
├── www/                  # Web 界面 (可选)
│   ├── index.html
│   └── app.js
├── api/                  # API 端点
│   └── {name}.sh
├── i18n/                 # 翻译 (可选)
│   ├── en.json
│   └── zh-cn.json
└── post-install          # 安装后钩子 (可选)
```

## API 端点汇总

### PPPoE
```
GET  /api/apps/pppoe              # 状态
GET  /api/apps/pppoe/config       # 配置
POST /api/apps/pppoe/config       # 保存配置
POST /api/apps/pppoe/connect      # 连接
POST /api/apps/pppoe/disconnect   # 断开
GET  /api/apps/pppoe/diagnose     # 诊断
```

### 端口转发
```
GET    /api/apps/portforward/forwards     # 列表
POST   /api/apps/portforward/forwards     # 添加规则
DELETE /api/apps/portforward/forwards/{id}# 删除规则
GET    /api/apps/portforward/dmz          # DMZ状态
POST   /api/apps/portforward/dmz          # 设置DMZ
GET    /api/apps/portforward/upnp         # UPnP状态
```

### DDNS
```
GET  /api/apps/ddns                   # 状态
GET  /api/apps/ddns/services          # 服务列表
POST /api/apps/ddns/services          # 添加服务
POST /api/apps/ddns/services/{id}/update # 强制更新
```

### 多线负载
```
GET  /api/apps/multiwan               # 状态
GET  /api/apps/multiwan/wans          # WAN列表
POST /api/apps/multiwan/wans          # 添加WAN
GET  /api/apps/multiwan/health        # 健康检查
POST /api/apps/multiwan/apply         # 应用配置
```

### QoS
```
GET  /api/apps/qos                    # 状态
GET  /api/apps/qos/rules              # 规则列表
POST /api/apps/qos/rules              # 添加规则
GET  /api/apps/qos/presets            # 预设模板
POST /api/apps/qos/apply              # 应用配置
```

### 网络诊断
```
GET /api/apps/diag/ping?host=x        # Ping测试
GET /api/apps/diag/traceroute?host=x  # Traceroute
GET /api/apps/diag/dns?domain=x       # DNS查询
GET /api/apps/diag/portscan?host=x    # 端口扫描
GET /api/apps/diag/connectivity       # 连接检查
GET /api/apps/diag/wifi               # WiFi扫描
```

### FRP
```
GET  /api/apps/frp                    # 状态
GET  /api/apps/frp/proxies            # 代理列表
POST /api/apps/frp/proxies            # 添加代理
POST /api/apps/frp/start              # 启动
POST /api/apps/frp/stop               # 停止
GET  /api/apps/frp/test               # 测试连接
```

### 广告过滤
```
GET  /api/apps/adblock                # 状态
GET  /api/apps/adblock/sources        # 规则源
POST /api/apps/adblock/update         # 更新规则
GET  /api/apps/adblock/whitelist      # 白名单
GET  /api/apps/adblock/blacklist      # 黑名单
GET  /api/apps/adblock/test?domain=x  # 测试域名
```

### 备份恢复
```
GET  /api/apps/backup/list            # 备份列表
POST /api/apps/backup/create          # 创建备份
POST /api/apps/backup/restore/{name}  # 恢复备份
DELETE /api/apps/backup/{name}        # 删除备份
POST /api/apps/backup/factory-reset   # 恢复出厂
```

## 构建和安装

```bash
cd clawui

# 列出所有应用
./build-apps.sh list

# 构建所有应用
./build-apps.sh all

# 构建单个应用
./build-apps.sh pppoe

# 输出目录
ls out/
# clawui-app-pppoe-1.0.0.tar.gz
# clawui-app-ddns-1.0.0.tar.gz
# ...
```

## 安装示例

```bash
# 安装 PPPoE 拨号
apk add ppp rp-pppoe clawui-app-pppoe

# 安装 DDNS
apk add curl ca-certificates clawui-app-ddns

# 安装广告过滤
apk add dnsmasq curl clawui-app-adblock

# 安装 FRP
apk add frp clawui-app-frp
```

## 开发新应用

```bash
cd clawui/tools
./create-app.sh myapp "我的应用"
```

## 与 OpenWrt 对比

| 特性 | OpenWrt | ClawUI |
|------|---------|--------|
| 包管理器 | opkg | apk |
| Web UI | LuCI | ClawUI |
| 应用包 | luci-app-* | clawui-app-* |
| 语言包 | luci-i18n-* | clawui-i18n-* |
| API 语言 | Lua | Shell |
| 前端框架 | 自定义 JS | Vue.js |
| 配置系统 | UCI | JSON + 文件 |

## 项目位置

```
/home/node/.openclaw/workspace/ax6600-alpine-clean/clawui/
├── apps/                    # 应用源码 (12个应用)
├── rootfs/                  # 安装目标
├── out/                     # 构建产物
├── build-apps.sh            # 构建脚本
└── APPS.md                  # 本文档
```