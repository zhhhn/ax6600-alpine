# NPS vs NPC - 内网穿透服务端与客户端

## ✅ 已修正

之前错误地将 NPS 和 NPC 混为一谈。现在已正确分别开发：

| 应用 | 包名 | 角色 | 功能 |
|------|------|------|------|
| **NPS 服务端** | `clawui-app-nps` | 服务器 | 接收客户端连接，提供穿透服务 |
| **NPC 客户端** | `clawui-app-npc` | 客户端 | 连接到 NPS 服务器，暴露本地服务 |

## 📦 输出的 APK 包

```
out/packages/
├── clawui-app-nps-1.0.0-r0_noarch.apk  (4.9K)  # NPS 服务端
├── clawui-app-npc-1.0.0-r0_noarch.apk  (4.2K)  # NPC 客户端
├── clawui-app-aria2-1.0.0-r0_noarch.apk (6.7K)
└── clawui-app-kms-1.0.0-r0_noarch.apk   (3.2K)
```

## 🎯 使用场景区别

### NPS 服务端 (clawui-app-nps)

**适用场景**：
- 你有公网 IP 的 VPS/服务器
- 想让其他人通过你的服务器访问内网设备
- 作为内网穿透的中转服务器

**安装**：
```bash
# 在公网服务器上安装
apk add nps
apk add --allow-untrusted clawui-app-nps-1.0.0-r0_noarch.apk

# 启动服务
/etc/init.d/nps start

# Web 访问
http://vps-ip:8080
```

**配置示例**：
```ini
# /etc/nps/nps.conf
http_proxy_port=80
https_proxy_port=443
bridge_port=8024
web_port=8080
web_username=admin
web_password=admin123
```

---

### NPC 客户端 (clawui-app-npc)

**适用场景**：
- 你在内网（家里/公司），没有公网 IP
- 想通过公网的 NPS 服务器暴露本地服务
- 需要远程访问内网的 NAS、摄像头、开发环境等

**安装**：
```bash
# 在内网设备上安装
wget https://github.com/ehang-io/nps/releases/download/v0.26.10/npc_linux_arm64.tar.gz
tar -xzf npc_linux_arm64.tar.gz
mv npc /usr/bin/
chmod +x /usr/bin/npc

apk add --allow-untrusted clawui-app-npc-1.0.0-r0_noarch.apk

# 配置并启动
# Web 界面配置服务器地址和 vkey
```

**配置示例**：
```ini
# /etc/nps/npc.conf
server_addr=vps.example.com
server_port=8024
vkey=your-verify-key-from-nps-server
conn_type=tcp
auto_reconnect=true
```

---

## 🔄 完整使用流程

```
┌─────────────────┐         互联网          ┌─────────────────┐
│   内网设备       │  ←  NPC 客户端连接  →   │   NPS 服务端     │
│  (家里/公司)    │                         │   (公网 VPS)     │
│                 │                         │                 │
│ 本地服务：       │    暴露到公网：          │  公网访问：      │
│ - NAS:5000      │  →  vps:5000  →        │  http://vps:5000│
│ - Web:8080      │  →  vps:8080  →        │  http://vps:8080│
│ - SSH:22        │  →  vps:2222  →        │  ssh -p 2222    │
└─────────────────┘                         └─────────────────┘
        ↑                                            ↑
  安装 clawui-app-npc                        安装 clawui-app-nps
```

### 步骤 1: 配置 NPS 服务端（公网 VPS）

1. 安装 NPS 和管理界面
2. 启动服务，访问 Web 界面 (http://vps-ip:8080)
3. 在 Web 界面创建客户端，获取 vkey
4. 配置隧道（TCP/UDP/HTTP/HTTPS）

### 步骤 2: 配置 NPC 客户端（内网设备）

1. 安装 NPC 二进制和管理界面
2. 在 Web 界面填写：
   - 服务器地址：vps-ip 或域名
   - 服务器端口：8024（默认）
   - vkey：从 NPS 服务端获取
3. 启动服务

### 步骤 3: 测试

从外网访问：`http://vps-ip:隧道端口`

---

## 📋 功能对比

| 功能 | NPS 服务端 | NPC 客户端 |
|------|-----------|-----------|
| 接收客户端连接 | ✅ | ❌ |
| 配置隧道规则 | ✅ | ❌ |
| 查看客户端状态 | ✅ | ❌ |
| 流量统计 | ✅ | ❌ |
| 连接服务器 | ❌ | ✅ |
| 暴露本地服务 | ❌ | ✅ |
| 自动重连 | ❌ | ✅ |

---

## 🛠️ 技术细节

### NPS 服务端

- **二进制**: `/usr/bin/nps`
- **配置文件**: `/etc/nps/nps.conf`
- **日志**: `/var/log/nps.log`
- **Web 端口**: 8080 (默认)
- **客户端连接端口**: 8024 (默认)
- **依赖**: `nps` 包

### NPC 客户端

- **二进制**: `/usr/bin/npc`
- **配置文件**: `/etc/nps/npc.conf`
- **日志**: `/var/log/npc.log`
- **连接类型**: TCP/KCP/QUIC
- **依赖**: `npc` (需手动下载)

---

## ⚠️ 常见错误

### 在 OpenWrt 上的错误做法

❌ **错误**: 只安装 `npc` 但包名叫 `luci-app-nps`
```bash
# 这是错误的！
opkg install luci-app-nps  # 实际安装的是客户端，但名字误导
```

✅ **正确**: 明确区分服务端和客户端
```bash
# 服务端（在 VPS 上）
apk add nps
apk add clawui-app-nps

# 客户端（在内网设备上）
apk add npc
apk add clawui-app-npc
```

---

## 📚 相关资源

- **NPS 项目**: https://github.com/ehang-io/nps
- **NPS 文档**: https://ehang-io.github.io/nps/
- **ClawUI NPS 管理**: `clawui-app-nps`
- **ClawUI NPC 管理**: `clawui-app-npc`

---

**NPS 和 NPC 已正确区分并分别开发！** ⚡
