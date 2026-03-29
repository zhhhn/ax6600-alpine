# 📦 ClawUI Apps 发布说明

## 版本：v1.0.0

**发布日期**: 2026-03-29

## ✨ 新增应用 (9 个)

### 下载类
- **clawui-app-aria2** - Aria2 下载管理器 (HTTP/FTP/BT/Magnet)
- **clawui-app-transmission** - Transmission BT 客户端

### 内网穿透类
- **clawui-app-nps** - NPS 服务端 (公网服务器)
- **clawui-app-npc** - NPC 客户端 (内网设备)
- **clawui-app-frp** - FRP 内网穿透客户端

### 系统工具类
- **clawui-app-kms** - KMS 激活服务器 (Windows/Office)
- **clawui-app-adguard** - AdGuard Home 广告过滤

### 文件服务类
- **clawui-app-vsftpd** - FTP 文件服务器
- **clawui-app-samba** - Samba 文件共享

## 🎯 功能特性

每个应用提供：
- ✅ Web 管理界面 (无需 CLI)
- ✅ 服务控制 (启动/停止/重启)
- ✅ 配置管理
- ✅ 实时状态监控
- ✅ 日志查看
- ✅ 小巧的包体积 (2-7 KB)

## 📦 包列表

```
clawui-app-aria2-1.0.0-r0_noarch.apk      (6.7K)
clawui-app-nps-1.0.0-r0_noarch.apk        (4.9K)
clawui-app-npc-1.0.0-r0_noarch.apk        (4.2K)
clawui-app-kms-1.0.0-r0_noarch.apk        (3.2K)
clawui-app-frp-1.0.0-r0_noarch.apk        (3.1K)
clawui-app-transmission-1.0.0-r0_noarch.apk (2.6K)
clawui-app-adguard-1.0.0-r0_noarch.apk    (2.2K)
clawui-app-vsftpd-1.0.0-r0_noarch.apk     (2.2K)
clawui-app-samba-1.0.0-r0_noarch.apk      (2.1K)
```

## 🚀 快速开始

### 1. 安装服务

```bash
# 示例：安装 Aria2
apk add aria2
```

### 2. 安装管理界面

```bash
# 下载 APK
wget https://github.com/zhhhn/ax6600-alpine/releases/latest/download/clawui-app-aria2-1.0.0-r0_noarch.apk

# 安装
apk add --allow-untrusted clawui-app-aria2-1.0.0-r0_noarch.apk
```

### 3. 启动服务

```bash
/etc/init.d/aria2 start
rc-update add aria2 default
```

### 4. Web 访问

```
http://192.168.1.1/app/clawui-app-aria2
```

## 📋 依赖关系

| 应用 | Alpine 包 | 安装命令 |
|------|----------|---------|
| Aria2 | aria2 | `apk add aria2 curl` |
| Transmission | transmission | `apk add transmission` |
| NPS | nps | `apk add nps` |
| NPC | npc | 手动下载二进制 |
| FRP | frpc | `apk add frpc` |
| KMS | py3-kms | `apk add py3-kms` |
| AdGuard | adguardhome | 手动下载二进制 |
| Vsftpd | vsftpd | `apk add vsftpd` |
| Samba | samba | `apk add samba` |

## 🛠️ 技术细节

### 包格式
- **命名**: `clawui-app-<name>` (符合 ClawUI 规范)
- **格式**: Alpine APK (tar.gz)
- **架构**: noarch (纯脚本)
- **许可证**: MIT

### 目录结构
```
clawui-app-<name>.apk
├── .PKGINFO
└── usr/share/clawui/apps/clawui-app-<name>/
    ├── manifest.json      # 应用元数据
    ├── www/index.html     # Web 界面
    └── api/handler.sh     # API 处理
```

### 构建系统
```bash
# 构建所有应用
./scripts/build-managers.sh all

# 构建单个应用
./scripts/build-managers.sh build clawui-app-aria2
```

## 📚 文档

- [README.md](clawui-apps/README.md) - 完整使用说明
- [NPS-VS-NPC.md](NPS-VS-NPC.md) - NPS 和 NPC 的区别
- [CLAWUI.md](docs/CLAWUI.md) - ClawUI 主界面文档

## 🎯 使用场景

### 家庭实验室
- **Aria2/Transmission**: 24/7 下载
- **AdGuard Home**: 全网广告过滤
- **Samba**: 家庭文件共享

### 远程访问
- **NPS/NPC**: 从外网访问内网设备
- **FRP**: 备用穿透方案

### 企业办公
- **KMS**: 激活 Windows/Office
- **FTP/Samba**: 文件共享
- **AdGuard**: DNS 过滤

## ⚠️ 注意事项

1. **NPS vs NPC**: 
   - NPS = 服务端 (安装在公网 VPS)
   - NPC = 客户端 (安装在内网设备)
   - 两者不能混淆！

2. **依赖安装**: 
   - 先安装 Alpine 官方包
   - 再安装 ClawUI 管理界面

3. **权限**: 
   - 某些服务需要 root 权限
   - 确保正确配置文件权限

## 🔮 下一步计划

- [ ] 应用商店界面
- [ ] 一键安装功能
- [ ] 自动更新机制
- [ ] 更多应用 (Nextcloud, Home Assistant 等)
- [ ] 应用依赖管理
- [ ] 资源使用监控

## 🙏 致谢

- [Alpine Linux](https://alpinelinux.org/)
- [ClawUI](https://github.com/openclaw/openclaw)
- [JDCloud AX6600](https://github.com/openclaw/ax6600-alpine-clean)

## 📄 许可证

MIT License

---

**完整提交历史**: https://github.com/zhhhn/ax6600-alpine/commit/c09c024

**已推送到 GitHub**: ✅ https://github.com/zhhhn/ax6600-alpine
