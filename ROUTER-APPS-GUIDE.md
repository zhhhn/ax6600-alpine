# 京东云 AX6600 路由器应用开发指南

## 📦 应用包格式

本项目使用 **Alpine Linux `.apk`** 包格式，而不是 `.tar.gz`。

### 为什么选择 APK？

✅ **标准格式**: Alpine Linux 官方包格式
✅ **依赖管理**: 自动处理应用依赖
✅ **版本控制**: 支持包版本管理和升级
✅ **集成性**: 可直接使用 `apk` 命令安装/卸载
✅ **小巧高效**: 压缩率高，适合嵌入式设备

## 🚀 快速开始

### 1. 创建应用目录结构

```bash
mkdir -p clawui/apps/myapp/{www,api,i18n}
```

### 2. 创建 APKBUILD 文件

```bash
cat > clawui/apps/myapp/APKBUILD << 'EOF'
pkgname=myapp
pkgver=1.0.0
pkgrel=0
pkgdesc="My Router Application"
url="https://github.com/openclaw/clawui"
arch="noarch"
license="MIT"
depends="clawui"

package() {
    # 创建应用目录
    mkdir -p "$pkgdir/usr/share/clawui/apps/myapp"
    
    # 复制 Web 界面
    cp -r "$srcdir"/www/* "$pkgdir/usr/share/clawui/apps/myapp/"
    
    # 复制 API
    cp -r "$srcdir"/api "$pkgdir/usr/share/clawui/apps/myapp/"
    
    # 复制国际化文件
    cp -r "$srcdir"/i18n "$pkgdir/usr/share/clawui/apps/myapp/"
    
    # 复制清单文件
    cp "$srcdir"/manifest.json "$pkgdir/usr/share/clawui/apps/myapp/"
    
    # 安装启动脚本
    if [ -f "$srcdir/myapp.init" ]; then
        mkdir -p "$pkgdir/etc/init.d"
        cp "$srcdir/myapp.init" "$pkgdir/etc/init.d/myapp"
        chmod +x "$pkgdir/etc/init.d/myapp"
    fi
    
    # 安装配置文件
    if [ -f "$srcdir/myapp.conf" ]; then
        mkdir -p "$pkgdir/etc/conf.d"
        cp "$srcdir/myapp.conf" "$pkgdir/etc/conf.d/myapp"
    fi
}

sha512sums=""
EOF
```

### 3. 创建应用清单

```json
{
  "id": "myapp",
  "name": "My Application",
  "version": "1.0.0",
  "description": "我的路由器应用",
  "icon": "star",
  "category": "tools",
  "author": "Your Name",
  "permissions": ["network", "storage"],
  "settings": {
    "port": 8080
  }
}
```

### 4. 创建 Web 界面

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>My App</title>
</head>
<body>
    <h1>⚡ My Router App</h1>
    <div id="status">Loading...</div>
    
    <script>
        async function refreshStatus() {
            const res = await fetch('/api/clawui/apps/myapp/status');
            const data = await res.json();
            document.getElementById('status').textContent = 
                data.running ? 'Running' : 'Stopped';
        }
        refreshStatus();
    </script>
</body>
</html>
```

### 5. 创建 API 处理脚本

```bash
cat > clawui/apps/myapp/api/handler.sh << 'EOF'
#!/bin/sh
# My App API

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
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
EOF
chmod +x clawui/apps/myapp/api/handler.sh
```

### 6. 创建 OpenRC 启动脚本

```bash
cat > clawui/apps/myapp/myapp.init << 'EOF'
#!/sbin/openrc-run
name="My App"
command="/usr/bin/myapp"
command_background="true"
pidfile="/var/run/myapp.pid"

depend() {
    need net
}
EOF
chmod +x clawui/apps/myapp/myapp.init
```

### 7. 构建 APK 包

```bash
cd ax6600-alpine-clean
./scripts/build-apk-simple.sh build myapp
```

## 📋 现有应用参考

### KMS 服务器

**功能**: Windows/Office KMS 激活

**文件结构**:
```
clawui/apps/kms/
├── APKBUILD
├── manifest.json
├── www/index.html
├── api/handler.sh
├── i18n/translations.json
├── kms-server.init
├── kms-server.conf
└── kms-server.sh
```

**安装**:
```bash
apk add kms-server
/etc/init.d/kms-server start
```

**使用**:
```cmd
# Windows
slmgr /skms <router-ip>:1688
slmgr /ato
```

### NPS 客户端

**功能**: 内网穿透反向代理

**特点**:
- HTTP/HTTPS 代理
- TCP/UDP 隧道
- SOCKS5 支持
- P2P 连接

**安装**:
```bash
apk add nps-client
/usr/share/clawui/apps/nps/download-npc.sh
/etc/init.d/nps-client start
```

### Aria2 下载器

**功能**: 多协议下载管理

**支持协议**:
- HTTP/HTTPS
- FTP
- BitTorrent
- Metalink

**安装**:
```bash
apk add aria2
/etc/init.d/aria2 start
```

**使用**:
```bash
aria2c -x 16 -s 16 https://example.com/file.zip
```

## 🔧 构建系统

### 简单构建（推荐）

无需额外依赖，适合快速开发：

```bash
./scripts/build-apk-simple.sh all      # 构建所有
./scripts/build-apk-simple.sh build kms  # 构建单个
```

### 完整构建

使用 Alpine abuild 系统：

```bash
apk add abuild devtools
./scripts/build-apk-packages.sh all
```

### 集成到固件

```bash
export BUILD_APKS=1
export INSTALL_APKS=1
./build.sh
```

## 📦 APK 包结构

```
package.apk (tar.gz 格式)
├── .PKGINFO          # 包元数据
├── .INSTALL          # 安装脚本（可选）
├── etc/
│   ├── conf.d/       # 服务配置
│   └── init.d/       # 启动脚本
└── usr/
    └── share/
        └── clawui/
            └── apps/
                └── <appname>/
                    ├── www/          # Web 界面
                    ├── api/          # API 接口
                    ├── i18n/         # 国际化
                    └── manifest.json # 应用清单
```

### .PKGINFO 格式

```
pkgname = myapp
pkgver = 1.0.0-r0
arch = noarch
license = MIT
origin = ClawUI
description = My application description
depend = dependency1 dependency2
```

## 🛠️ 开发工具

### 查看 APK 内容

```bash
tar -tzf package.apk
```

### 提取 APK

```bash
tar -xzf package.apk -C /path/to/extract
```

### 检查依赖

```bash
grep "^depend" .PKGINFO
```

### 测试安装

```bash
# 创建测试目录
mkdir -p /tmp/test-root
tar -xzf package.apk -C /tmp/test-root

# 检查文件结构
find /tmp/test-root -type f

# 清理
rm -rf /tmp/test-root
```

## 📊 应用分类

| 分类 | 描述 | 示例 |
|------|------|------|
| network | 网络服务 | NPS, FRP, WireGuard |
| tools | 工具软件 | KMS, Aria2 |
| storage | 存储服务 | FTP, SMB, Nextcloud |
| monitoring | 监控工具 | Traffic, Diag |
| security | 安全工具 | Adblock, VPN |

## 🎯 最佳实践

### 1. 轻量级设计

- 保持 APK 包小巧 (< 100KB 为佳)
- 使用脚本语言 (shell) 而非二进制
- 按需下载大文件（如 NPS 二进制）

### 2. 资源管理

- 限制内存使用
- 避免 CPU 密集型操作
- 合理使用磁盘空间

### 3. 错误处理

```bash
#!/bin/sh
if ! command -v required_cmd > /dev/null; then
    echo "ERROR: required_cmd not found"
    exit 1
fi
```

### 4. 日志记录

```bash
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/myapp.log
}
```

### 5. 配置管理

- 使用 `/etc/conf.d/<app>` 存储配置
- 支持配置热重载
- 提供配置示例文件

## 🔒 安全考虑

### 权限控制

```bash
# APKBUILD 中指定依赖
depends="clawui dropbear"

# 限制文件权限
chmod 600 "$pkgdir/etc/myapp/secret.conf"
```

### 输入验证

```bash
# 验证 API 输入
if ! echo "$INPUT" | grep -E '^[a-zA-Z0-9_-]+$' > /dev/null; then
    echo '{"error": "Invalid input"}'
    exit 1
fi
```

### 网络安全

- 使用非标准端口
- 支持 HTTPS
- 实现访问控制

## 📈 性能优化

### 启动优化

```bash
# 延迟启动非关键服务
command_args="--daemon --delay=5"
```

### 内存优化

```bash
# 限制进程内存
ulimit -v 50000  # 50MB
```

## 🐛 调试技巧

### 查看服务状态

```bash
rc-status | grep myapp
```

### 查看日志

```bash
tail -f /var/log/myapp.log
```

### 手动启动调试

```bash
# 前台运行查看输出
/usr/bin/myapp --debug
```

### 检查端口占用

```bash
netstat -tlnp | grep :PORT
```

## 📚 参考资源

- [Alpine APK 格式](https://wiki.alpinelinux.org/wiki/Apk_spec)
- [APKBUILD 参考](https://wiki.alpinelinux.org/wiki/APKBUILD_Reference)
- [OpenRC 服务](https://wiki.alpinelinux.org/wiki/OpenRC)
- [ClawUI 应用开发](clawui/apps/README.md)

## 🎉 示例项目

查看以下已完成的应用作为参考：

1. **KMS Server** - 简单的 KMS 激活服务
2. **NPS Client** - 内网穿透客户端
3. **Aria2** - 下载管理器

---

**Happy Coding!** ⚡🚀
