# ClawUI 应用生态

> 45 个 Web 管理应用，覆盖网络、代理、存储、媒体、IoT 等领域

---

## 应用总览

| 分类 | 数量 | 应用列表 |
|------|------|----------|
| **网络管理** | 8 | PPPoE, 端口转发, DDNS, 静态路由, 多线负载, QoS, 流量监控, 网络诊断 |
| **代理工具** | 10 | Xray, Trojan, Clash, Hysteria2, SOCKS5, Shadowsocks, WireGuard, OpenVPN, Tailscale, ZeroTier, HomeProxy |
| **存储服务** | 5 | Samba, FTP, File Browser, Syncthing, Transmission |
| **下载工具** | 4 | Aria2, Transmission, qBittorrent, FRP |
| **媒体服务** | 3 | Jellyfin, MiniDLNA, PhotoPrism |
| **系统工具** | 8 | Docker, Nginx, AdGuard, Pi-hole, KMS, 网速测试, 网络唤醒, Uptime Kuma |
| **IoT/其他** | 5 | MQTT, Gitea, Memos, Tiny Tiny RSS, 备份恢复 |
| **网络穿透** | 3 | NPS, NPC, FRP |

---

## 详细列表

### 网络管理类

| 应用 | ID | 功能 |
|------|-----|------|
| PPPoE | `pppoe` | 宽带拨号配置 |
| 端口转发 | `portforward` | 端口映射/DMZ/UPnP |
| DDNS | `ddns` | 阿里云/腾讯/Cloudflare |
| 静态路由 | `routes` | 静态路由/策略路由 |
| 多线负载 | `multiwan` | 负载均衡/故障切换 |
| QoS | `qos` | 流量整形/优先级 |
| 流量监控 | `traffic` | 实时流量统计 |
| 网络诊断 | `diag` | Ping/Traceroute/DNS |

### 代理工具类

| 应用 | ID | 协议支持 |
|------|-----|----------|
| Xray | `clawui-app-xray` | VLESS, VMess, Trojan |
| Trojan | `clawui-app-trojan` | Trojan |
| Clash | `clawui-app-clash` | SS, VMess, Trojan |
| Hysteria2 | `clawui-app-hysteria2` | Hysteria2 (QUIC) |
| SOCKS5 | `clawui-app-socks5` | SOCKS5, HTTP |
| Shadowsocks | `clawui-app-shadowsocks` | Shadowsocks |
| WireGuard | `clawui-app-wireguard` | WireGuard |
| OpenVPN | `clawui-app-openvpn` | OpenVPN |
| Tailscale | `clawui-app-tailscale` | Tailscale |
| ZeroTier | `clawui-app-zerotier` | ZeroTier |
| HomeProxy | `clawui-app-homeproxy` | 透明代理网关 |

### 存储服务类

| 应用 | ID | 功能 |
|------|-----|------|
| Samba | `clawui-app-samba` | SMB 文件共享 |
| FTP | `clawui-app-vsftpd` | FTP 服务器 |
| File Browser | `clawui-app-filebrowser` | Web 文件管理 |
| Syncthing | `clawui-app-syncthing` | P2P 同步 |
| Transmission | `clawui-app-transmission` | BT 下载 |

### 系统工具类

| 应用 | ID | 功能 |
|------|-----|------|
| Docker | `clawui-app-docker` | 容器管理 |
| Nginx | `clawui-app-nginx` | Web 服务器 |
| AdGuard Home | `clawui-app-adguard` | DNS 过滤 |
| Pi-hole | `clawui-app-pihole` | 广告拦截 |
| KMS | `clawui-app-kms` | Windows 激活 |
| 网速测试 | `clawui-app-speedtest` | 局域网测速 |
| 网络唤醒 | `clawui-app-wol` | Wake-on-LAN |
| Uptime Kuma | `clawui-app-uptime` | 服务监控 |

### 媒体/IoT 类

| 应用 | ID | 功能 |
|------|-----|------|
| Jellyfin | `clawui-app-jellyfin` | 流媒体 |
| MiniDLNA | `clawui-app-minidlna` | DLNA |
| PhotoPrism | `clawui-app-photoprism` | 照片管理 |
| MQTT | `clawui-app-mosquitto` | IoT 消息 |
| Gitea | `clawui-app-gitea` | Git 服务 |
| Memos | `clawui-app-memos` | 笔记 |
| Tiny Tiny RSS | `clawui-app-ttrss` | RSS 阅读 |
| 备份恢复 | `backup` | 配置备份 |

---

## 应用结构

```
apps/{app-id}/
├── manifest.json     # 元数据
├── APKBUILD          # 包定义
├── api/handler.sh    # API 脚本
└── www/index.html    # Web 界面
```

---

## API 规范

| 端点 | 功能 |
|------|------|
| `GET /api/{app}/status` | 状态查询 |
| `GET /api/{app}/config` | 获取配置 |
| `POST /api/{app}/config` | 保存配置 |
| `POST /api/{app}/start` | 启动服务 |
| `POST /api/{app}/stop` | 停止服务 |

返回格式：
```json
{"success": true, "message": "操作成功"}
{"running": true, "uptime": "2h30m"}
```

---

## 构建安装

```bash
# 构建
cd clawui && ./build-apps.sh {app-id}

# 安装
apk add clawui-app-{id}.apk

# 访问
http://192.168.1.1/app/{app-id}
```

---

相关文档：[DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南