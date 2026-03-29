# 开发指南

> 固件开发、测试与 CI/CD 完整指南

---

## 项目架构

```
ax6600-alpine/
├── .github/workflows/    # GitHub Actions CI
├── configs/              # 设备树配置
├── scripts/              # 构建脚本
├── rootfs-overlay/       # 文件系统覆盖层
│   ├── etc/init.d/       # OpenRC 服务脚本
│   └── usr/sbin/         # 管理命令
├── clawui/               # Web 管理系统
│   ├── apps/             # 45个应用
│   └── build-apps.sh     # 应用构建
├── docs/                 # 文档
├── build.sh              # 主构建入口
└── README.md             # 项目概述
```

---

## 开发环境

### 本地开发

```bash
# 克隆仓库
git clone https://github.com/zhhhn/ax6600-alpine.git
cd ax6600-alpine

# 安装依赖
sudo apt-get install -y build-essential flex bison gcc-aarch64-linux-gnu
```

### 构建命令

```bash
# 完整构建
./build.sh

# 分步构建
./scripts/build-kernel.sh all    # 内核
./scripts/build-rootfs.sh        # 根文件系统
./scripts/package-firmware.sh    # 打包

# 清理
rm -rf build/ out/
```

---

## 添加新功能

### 添加服务脚本

1. 创建 init 脚本：
```bash
#!/sbin/openrc-run
name="myservice"
command="/usr/bin/myservice"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"

depend() {
    need net
}
```

2. 放置到 `rootfs-overlay/etc/init.d/`
3. 构建时自动包含

### 添加 CLI 命令

1. 创建脚本：
```bash
#!/bin/sh
# /usr/sbin/mycommand

case "$1" in
    start) echo "Starting..." ;;
    stop)  echo "Stopping..." ;;
    *)     echo "Usage: $0 {start|stop}" ;;
esac
```

2. 放置到 `rootfs-overlay/usr/sbin/`

### 添加 Web UI 应用

```bash
# 创建应用目录
mkdir -p clawui/apps/myapp/api
mkdir -p clawui/apps/myapp/www

# 创建 manifest.json
cat > clawui/apps/myapp/manifest.json << 'EOF'
{
  "id": "myapp",
  "name": "我的应用",
  "version": "1.0.0",
  "description": "应用描述",
  "category": "tools",
  "dependencies": ["curl"]
}
EOF

# 创建 API handler
cat > clawui/apps/myapp/api/handler.sh << 'EOF'
#!/bin/sh
case "$1" in
    status) echo '{"running": true}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
EOF

chmod +x clawui/apps/myapp/api/handler.sh

# 构建
cd clawui && ./build-apps.sh myapp
```

---

## 测试框架

### 语法检查

```bash
# 快速检查
./scripts/test-firmware.sh smoke

# 检查所有脚本
shellcheck rootfs-overlay/etc/init.d/*
shellcheck rootfs-overlay/usr/sbin/*
```

### 模拟器测试

#### Python 模拟器（轻量）

```bash
python3 scripts/simulate.py
# 访问 http://localhost:8080
```

#### QEMU 虚拟机（完整）

```bash
# 创建虚拟机
./scripts/vm.sh create

# 启动虚拟机
./scripts/vm.sh start

# SSH 连接
ssh root@localhost -p 2222

# 停止虚拟机
./scripts/vm.sh stop
```

### 测试覆盖

| 测试类型 | 测试项 | 命令 |
|----------|--------|------|
| 语法检查 | Shell 脚本 | `./scripts/test-firmware.sh smoke` |
| 完整测试 | 45项测试 | `./scripts/test-firmware.sh all` |
| 模拟测试 | Python/QEMU | `python3 scripts/simulate.py` |

---

## CI/CD 配置

### GitHub Actions

配置文件：`.github/workflows/build.yml`

```yaml
name: Build AX6600 Alpine Firmware

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential flex bison gcc-aarch64-linux-gnu
      
      - name: Build kernel
        run: ./scripts/build-kernel.sh all
      
      - name: Build rootfs
        run: ./scripts/build-rootfs.sh
      
      - name: Package firmware
        run: ./scripts/package-firmware.sh
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          path: out/
```

### 自动构建

- 推送到 main 分支自动触发
- Pull Request 也会触发测试构建
- 产物可在 Actions 页面下载

### 手动触发

1. 进入 Actions 页面
2. 选择 "Build AX6600 Alpine Firmware"
3. 点击 "Run workflow"

---

## 代码规范

### Shell 脚本

```bash
#!/bin/sh
# 脚本说明

set -e  # 遇错退出

# 变量命名使用下划线
my_variable="value"

# 函数命名使用小写
my_function() {
    echo "Hello"
}

# 使用 shellcheck 检查
```

### API 返回格式

```json
// 成功
{"success": true, "message": "操作成功"}

// 失败
{"success": false, "error": "错误信息"}

// 状态
{"running": true, "uptime": "2h30m"}
```

### 提交规范

```
feat: 添加新功能
fix: 修复 bug
docs: 文档更新
refactor: 代码重构
test: 测试相关
chore: 构建/工具相关
```

---

## 调试技巧

### 内核调试

```bash
# 查看内核日志
dmesg | tail -100

# 查看模块
lsmod

# 加载模块
modprobe ath11k
```

### 服务调试

```bash
# 查看服务状态
rc-status

# 手动启动服务
/usr/sbin/wifi debug

# 查看日志
tail -f /var/log/messages
```

### 网络调试

```bash
# 查看网络接口
ip addr

# 查看路由
ip route

# 查看防火墙
nft list ruleset
```

---

## 常见问题

### 构建失败

**编译器找不到**
```bash
sudo apt-get install gcc-aarch64-linux-gnu
```

**磁盘空间不足**
```bash
rm -rf build/ out/
```

### 测试失败

**shellcheck 错误**
```bash
# 查看具体错误
shellcheck scripts/*.sh
```

**QEMU 无法启动**
```bash
# 安装 QEMU
sudo apt-get install qemu-system-arm qemu-user-static
```

---

相关文档：
- [GUIDE.md](GUIDE.md) - 使用指南
- [APPS.md](APPS.md) - 应用开发
- [ARCHITECTURE.md](ARCHITECTURE.md) - 系统架构