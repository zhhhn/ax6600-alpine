# ClawUI 应用管理器

## 📌 正确的开发方向

**之前搞错了！** KMS、NPS、Aria2 在 Alpine 官方源都有，不需要重新打包。

**正确的方向是：** 开发这些应用的**Web 管理界面**，通过 ClawUI 来配置、启动/停止、监控这些服务。

## 🎯 架构说明

```
┌─────────────────────────────────────────────────────┐
│              Alpine Linux 官方源                      │
│  aria2  │  npc (NPS)  │  py-kms  │  vsftpd  │ ...   │
└─────────┴─────────────┴──────────┴──────────┴───────┘
            ↓ 使用 apk 安装
┌─────────────────────────────────────────────────────┐
│              路由器 (AX6600)                         │
│  /usr/bin/aria2c  /usr/bin/npc  /usr/bin/py-kms     │
└─────────────────────────────────────────────────────┘
            ↓ 通过 OpenRC 管理
┌─────────────────────────────────────────────────────┐
│           ClawUI 应用管理器 (我们开发的)              │
│  aria2-manager  │  nps-manager  │  kms-manager      │
│  - Web 界面      │  - Web 界面     │  - Web 界面        │
│  - API 处理      │  - API 处理     │  - API 处理        │
│  - 配置管理     │  - 配置管理    │  - 配置管理       │
└─────────────────────────────────────────────────────┘
            ↓ 用户访问
┌─────────────────────────────────────────────────────┐
│              用户浏览器                              │
│         http://router-ip/app/aria2-manager          │
└─────────────────────────────────────────────────────┘
```

## 📦 已开发的管理器

### 1. Aria2 Manager (aria2-manager)

**依赖**: `aria2` (Alpine 官方源)

**功能**:
- ✅ 添加下载任务 (HTTP/HTTPS/FTP/BitTorrent/Magnet)
- ✅ 查看下载进度和速度
- ✅ 暂停/继续/删除任务
- ✅ 配置 RPC 端口、下载目录、最大连接数
- ✅ 服务启动/停止/重启
- ✅ 查看日志

**安装**:
```bash
# 1. 安装官方 aria2 包
apk add aria2

# 2. 安装管理器
apk add --allow-untrusted aria2-manager-1.0.0-r0_noarch.apk

# 3. 配置并启动
/etc/init.d/aria2 start
rc-update add aria2 default
```

**访问**: `http://router-ip/app/aria2-manager`

---

### 2. NPS Manager (nps-manager)

**依赖**: `npc` (需要手动下载二进制)

**功能**:
- ✅ 配置 NPS 服务器地址、端口、验证密钥
- ✅ 服务启动/停止/重启
- ✅ 查看隧道状态
- ✅ 查看日志

**安装**:
```bash
# 1. 下载 NPS 客户端
wget https://github.com/ehang-io/nps/releases/download/v0.26.10/npc_linux_arm64.tar.gz
tar -xzf npc_linux_arm64.tar.gz
mv npc /usr/bin/
chmod +x /usr/bin/npc

# 2. 安装管理器
apk add --allow-untrusted nps-manager-1.0.0-r0_noarch.apk

# 3. 创建配置文件
mkdir -p /etc/nps
cat > /etc/nps/npc.conf << EOF
server_addr=nps.example.com
server_port=8024
vkey=your-verify-key
conn_type=tcp
auto_reconnect=true
EOF

# 4. 启动服务
/etc/init.d/npc start
```

**访问**: `http://router-ip/app/nps-manager`

---

### 3. KMS Manager (kms-manager)

**依赖**: `py3-kms` (Alpine 官方源或手动安装)

**功能**:
- ✅ 配置监听端口
- ✅ 服务启动/停止
- ✅ 查看激活统计
- ✅ 查看日志
- ✅ 显示 Windows/Office 激活命令

**安装**:
```bash
# 1. 安装 py-kms (如果没有)
apk add py3-kms  # 或使用 pip3 install py-kms

# 2. 安装管理器
apk add --allow-untrusted kms-manager-1.0.0-r0_noarch.apk

# 3. 启动服务
/etc/init.d/py-kms start
rc-update add py-kms default
```

**访问**: `http://router-ip/app/kms-manager`

---

## 🚀 快速部署

### 方法 1: 手动安装

```bash
# 复制 APK 到路由器
scp out/packages/*-manager-*.apk root@192.168.10.1:/tmp/

# SSH 登录
ssh root@192.168.10.1

# 安装管理器
cd /tmp
apk add --allow-untrusted aria2-manager-1.0.0-r0_noarch.apk
apk add --allow-untrusted nps-manager-1.0.0-r0_noarch.apk
apk add --allow-untrusted kms-manager-1.0.0-r0_noarch.apk

# 安装依赖
apk add aria2 curl

# 启动服务
/etc/init.d/aria2 start
/etc/init.d/npc start
/etc/init.d/py-kms start
```

### 方法 2: 集成到固件

```bash
# 在 build-rootfs.sh 中添加
apk add aria2 curl
# 然后安装管理器 APK
```

### 方法 3: 自动部署脚本

```bash
#!/bin/sh
# deploy-managers.sh

# 安装依赖
apk update
apk add aria2 curl

# 安装管理器
for apk in /tmp/*-manager-*.apk; do
    apk add --allow-untrusted "$apk"
done

# 启动服务
for svc in aria2 npc py-kms; do
    /etc/init.d/$svc start 2>/dev/null || true
    rc-update add $svc default 2>/dev/null || true
done

echo "部署完成！"
```

## 📋 管理器结构

每个管理器 APK 包含：

```
<manager>-manager.apk
├── .PKGINFO
└── usr/
    └── share/
        └── clawui/
            └── apps/
                └── <manager>-manager/
                    ├── manifest.json      # 应用清单
                    ├── www/
                    │   └── index.html     # Web 界面
                    ├── api/
                    │   └── handler.sh     # API 处理
                    └── i18n/
                        └── translations.json
```

## 🔧 开发新管理器

### 1. 创建目录结构

```bash
mkdir -p clawui/apps/<app>-manager/{www,api,i18n}
```

### 2. 创建 manifest.json

```json
{
  "id": "myapp-manager",
  "name": "MyApp 管理器",
  "version": "1.0.0",
  "description": "MyApp 的 Web 管理界面",
  "icon": "star",
  "category": "tools",
  "dependencies": ["myapp"]
}
```

### 3. 创建 Web 界面

参考 `aria2-manager/www/index.html`

### 4. 创建 API handler

```bash
#!/bin/sh
# api/handler.sh

ACTION="$1"
shift

case "$ACTION" in
    start)
        /etc/init.d/myapp start
        echo '{"success": true}'
        ;;
    stop)
        /etc/init.d/myapp stop
        echo '{"success": true}'
        ;;
    status)
        if pgrep -f "myapp" > /dev/null; then
            echo '{"running": true}'
        else
            echo '{"running": false}'
        fi
        ;;
    config)
        # 读取配置并保存
        echo '{"success": true}'
        ;;
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
```

### 5. 创建 APKBUILD

参考 `aria2-manager/APKBUILD`

### 6. 构建

```bash
./scripts/build-managers.sh build myapp-manager
```

## 📊 可开发的管理器列表

| 应用 | Alpine 包名 | 管理器状态 | 优先级 |
|------|-----------|----------|--------|
| Aria2 | aria2 | ✅ 完成 | ⭐⭐⭐ |
| NPS | npc (手动) | ✅ 完成 | ⭐⭐⭐ |
| KMS | py3-kms | ✅ 完成 | ⭐⭐⭐ |
| FRP | frpc | ⏳ 待开发 | ⭐⭐ |
| Transmission | transmission | ⏳ 待开发 | ⭐⭐ |
| Nextcloud | nextcloud | ⏳ 待开发 | ⭐ |
| Home Assistant | home-assistant | ⏳ 待开发 | ⭐ |
| Vsftpd | vsftpd | ⏳ 待开发 | ⭐⭐ |
| Samba | samba | ⏳ 待开发 | ⭐⭐ |
| MiniDLNA | minidlna | ⏳ 待开发 | ⭐ |
| AdGuard Home | adguardhome | ⏳ 待开发 | ⭐⭐⭐ |

## 🎯 下一步

1. ✅ 测试 Aria2 Manager
2. ✅ 测试 NPS Manager  
3. ✅ 测试 KMS Manager
4. ⏳ 开发 Frp Manager
5. ⏳ 开发 Transmission Manager
6. ⏳ 开发 AdGuard Home Manager
7. ⏳ 创建应用商店页面（统一安装/管理所有管理器）

## 💡 关键优势

- ✅ **复用官方包**: 不需要维护应用本身
- ✅ **专注管理**: 只做 Web 界面和配置
- ✅ **易于更新**: Alpine 官方更新应用，我们只更新管理器
- ✅ **小巧**: 管理器 APK 只有几 KB
- ✅ **统一体验**: 所有管理器界面风格一致

---

**这才是正确的方向！** ⚡
