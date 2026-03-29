# 构建指南

本文档说明如何构建 AX6600 Alpine Linux 固件。

## 环境要求

### 操作系统

- Ubuntu 22.04 LTS (推荐)
- Debian 11/12
- 其他 Linux 发行版 (需要适配)

### 硬件要求

| 资源 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 2 核 | 4 核+ |
| 内存 | 4GB | 8GB+ |
| 磁盘 | 20GB | 50GB+ |

### 软件依赖

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    flex \
    bison \
    libncurses-dev \
    libssl-dev \
    bc \
    u-boot-tools \
    wget \
    git \
    cpio \
    gzip \
    tar \
    gcc-aarch64-linux-gnu \
    qemu-user-static \
    qemu-system-arm
```

## 快速构建

### 一键构建

```bash
# 克隆仓库
git clone https://github.com/zhhhn/ax6600-alpine.git
cd ax6600-alpine

# 执行构建
./build.sh

# 查看输出
ls -lh out/
```

### 构建输出

```
out/
├── ax6600-alpine-factory.bin   # 完整刷机包 (46MB)
├── ax6600-alpine.itb           # FIT 镜像 (14MB)
├── Image.gz                    # 压缩内核 (14MB)
├── ipq6018-jdcloud-ax6600.dtb  # 设备树 (15KB)
├── alpine-rootfs.tar.gz        # 根文件系统 (33MB)
├── alpine-rootfs.img           # ext4 镜像 (512MB)
├── modules.tar.gz              # 内核模块 (69MB)
├── initramfs.cpio.gz           # 初始化内存盘
├── flash-commands.txt          # 刷机命令
├── install.sh                  # 安装脚本
└── SHA256SUMS                  # 校验和
```

## 分步构建

### 1. 内核构建

```bash
./scripts/build-kernel.sh all
```

构建过程：
1. 下载 Linux 6.6.22 源码
2. 应用补丁和配置
3. 编译内核镜像
4. 编译设备树
5. 编译内核模块

### 2. 根文件系统构建

```bash
./scripts/build-rootfs.sh
```

构建过程：
1. 创建目录结构
2. 下载 Alpine 最小系统
3. 安装基础包
4. 应用 overlay 配置
5. 创建镜像文件

### 3. 固件打包

```bash
./scripts/package-firmware.sh
```

构建过程：
1. 创建 FIT 镜像
2. 打包内核和 DTB
3. 生成刷机镜像
4. 计算校验和

## 构建配置

### 内核配置

编辑 `configs/ipq6018-jdcloud-ax6600.dts` 修改设备树。

### Rootfs 配置

修改 `rootfs-overlay/` 目录下的文件：
- `etc/network/interfaces` - 网络配置
- `etc/hostapd/*.conf` - WiFi 配置
- `etc/nftables.conf` - 防火墙规则

### 软件包列表

编辑 `scripts/build-rootfs.sh` 中的 `EXTRA_PKGS` 变量添加更多包。

## GitHub Actions 构建

### 自动构建

推送到 main 分支自动触发构建：

```bash
git push origin main
```

### 手动触发

1. 进入 Actions 页面
2. 选择 "Build AX6600 Alpine Firmware"
3. 点击 "Run workflow"

### 构建日志

从 Actions 页面下载完整日志：
```
Actions → 选择运行 → 下载日志
```

## 本地测试

### 语法检查

```bash
./scripts/test-firmware.sh smoke
```

### 完整测试

```bash
./scripts/test-firmware.sh all
```

### 模拟器测试

```bash
# Python 模拟器
python3 scripts/simulate.py

# QEMU 虚拟机
./scripts/vm.sh create
./scripts/vm.sh start
```

## 常见问题

### 编译错误

**问题**: 内核编译失败
```bash
# 解决：安装所有依赖
sudo apt-get install -y build-essential flex bison libssl-dev
```

**问题**: 交叉编译器找不到
```bash
# 解决：安装 ARM64 交叉编译器
sudo apt-get install -y gcc-aarch64-linux-gnu
```

### 磁盘空间不足

```bash
# 清理构建缓存
rm -rf build/
rm -rf out/

# 或只保留必要文件
./build.sh clean
```

### APK 下载失败

```bash
# 使用国内镜像
export APK_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/alpine/"
```

## 构建参数

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `SKIP_KERNEL` | 跳过内核构建 | 0 |
| `SKIP_ROOTFS` | 跳过 rootfs 构建 | 0 |
| `KERNEL_VERSION` | 内核版本 | 6.6.22 |
| `ALPINE_VERSION` | Alpine 版本 | v3.19 |

### 示例

```bash
# 只构建 rootfs
SKIP_KERNEL=1 ./build.sh

# 使用不同版本
KERNEL_VERSION=6.6.10 ./build.sh
```

## 进阶主题

### 自定义内核配置

```bash
# 进入内核配置菜单
cd build/linux-6.6.22
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig

# 保存配置
cp .config ../../configs/kernel-config
```

### 添加自定义包

1. 编辑 `scripts/build-rootfs.sh`
2. 在 `EXTRA_PKGS` 中添加包名
3. 重新构建

### 创建自定义镜像

```bash
# 修改 rootfs-overlay/
# 重新打包
./scripts/package-firmware.sh
```

---

相关文档：
- [FLASHING.md](FLASHING.md) - 刷机指南
- [ARCHITECTURE.md](ARCHITECTURE.md) - 项目架构
- [TESTING.md](TESTING.md) - 测试方法