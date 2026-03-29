# 📦 ClawUI Apps 完整列表

## 已开发应用 (13 个)

### 下载管理类 (2)
| 应用 | 包名 | 大小 | 依赖 |
|------|------|------|------|
| **Aria2** | clawui-app-aria2 | 6.7K | aria2, curl |
| **Transmission** | clawui-app-transmission | 2.6K | transmission |

### 内网穿透类 (3)
| 应用 | 包名 | 大小 | 依赖 |
|------|------|------|------|
| **NPS 服务端** | clawui-app-nps | 4.9K | nps |
| **NPC 客户端** | clawui-app-npc | 4.2K | npc |
| **FRP** | clawui-app-frp | 3.1K | frpc |

### VPN/网络类 (4)
| 应用 | 包名 | 大小 | 依赖 |
|------|------|------|------|
| **KMS** | clawui-app-kms | 3.2K | py3-kms |
| **ZeroTier** | clawui-app-zerotier | 2.4K | zerotier |
| **OpenVPN** | clawui-app-openvpn | 2.2K | openvpn |
| **AdGuard Home** | clawui-app-adguard | 2.2K | adguardhome |

### 文件服务类 (2)
| 应用 | 包名 | 大小 | 依赖 |
|------|------|------|------|
| **FTP** | clawui-app-vsftpd | 2.2K | vsftpd |
| **Samba** | clawui-app-samba | 2.1K | samba |

### 媒体服务类 (1)
| 应用 | 包名 | 大小 | 依赖 |
|------|------|------|------|
| **MiniDLNA** | clawui-app-minidlna | 2.5K | minidlna |

### 工具类 (1)
| 应用 | 包名 | 大小 | 依赖 |
|------|------|------|------|
| **网络唤醒** | clawui-app-wol | 2.3K | etherwake |

---

## 📊 统计

- **总应用数**: 13 个
- **总包大小**: ~41 KB
- **平均包大小**: 3.2 KB/应用
- **最大包**: clawui-app-aria2 (6.7K)
- **最小包**: clawui-app-samba (2.1K)

## 🎯 功能覆盖

- ✅ 下载管理 (HTTP/BT/Magnet)
- ✅ 内网穿透 (NPS, FRP)
- ✅ VPN 连接 (ZeroTier, OpenVPN)
- ✅ 广告过滤 (AdGuard Home)
- ✅ 文件共享 (FTP, Samba)
- ✅ 媒体服务器 (MiniDLNA)
- ✅ 系统工具 (WoL, KMS)

## 🚀 使用示例

```bash
# 安装服务
apk add aria2

# 安装 Web 管理界面
apk add --allow-untrusted clawui-app-aria2-1.0.0-r0_noarch.apk

# 启动服务
/etc/init.d/aria2 start

# Web 访问
http://192.168.1.1/app/clawui-app-aria2
```

## 📁 输出目录

```
out/packages/
├── clawui-app-aria2-1.0.0-r0_noarch.apk
├── clawui-app-nps-1.0.0-r0_noarch.apk
├── clawui-app-npc-1.0.0-r0_noarch.apk
├── clawui-app-kms-1.0.0-r0_noarch.apk
├── clawui-app-frp-1.0.0-r0_noarch.apk
├── clawui-app-transmission-1.0.0-r0_noarch.apk
├── clawui-app-adguard-1.0.0-r0_noarch.apk
├── clawui-app-vsftpd-1.0.0-r0_noarch.apk
├── clawui-app-samba-1.0.0-r0_noarch.apk
├── clawui-app-minidlna-1.0.0-r0_noarch.apk
├── clawui-app-zerotier-1.0.0-r0_noarch.apk
├── clawui-app-openvpn-1.0.0-r0_noarch.apk
└── clawui-app-wol-1.0.0-r0_noarch.apk
```

## 🔮 下一步计划

- [ ] Home Assistant (智能家居)
- [ ] Nextcloud (私有云)
- [ ] DDNS 客户端 (动态 DNS)
- [ ] Docker 管理
- [ ] 应用商店界面
- [ ] 一键安装功能

---

**最后更新**: 2026-03-29
**GitHub**: https://github.com/zhhhn/ax6600-alpine
