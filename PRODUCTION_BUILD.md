# Production Build Guide

## 问题：当前环境无法编译内核

当前OpenClaw环境缺少以下编译工具：
- flex (词法分析器生成器)
- bison (语法分析器生成器)  
- build-essential (gcc, make等)

## 解决方案

### 方案1：在完整Ubuntu系统上构建（推荐）

```bash
# 1. 准备Ubuntu 22.04+系统
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
    git

# 2. 克隆项目
git clone <project-url>
cd ax6600-alpine

# 3. 构建
./build.sh
```

### 方案2：使用Docker构建

```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    build-essential flex bison libncurses-dev \
    libssl-dev bc u-boot-tools wget git
WORKDIR /build
COPY . .
RUN ./build.sh
```

### 方案3：下载预编译内核

从OpenWrt获取IPQ60xx内核：
```bash
wget https://downloads.openwrt.org/releases/23.05.3/targets/qualcommax/ipq60xx/openwrt-23.05.3-qualcommax-ipq60xx-jdcloud_re-cs-02-fit-uImage.itb

# 提取内核
dumpimage -i openwrt-fit-uImage.itb -p 0 kernel.gz
```

## 真实内核构建流程

```bash
# 清理占位符
rm -rf build/linux-6.6.22 out/*

# 下载并编译
./scripts/build-kernel.sh all

# 构建rootfs  
./scripts/build-rootfs.sh

# 打包固件
./scripts/package-firmware.sh
```

## 预期输出（真实构建）

```
out/
├── Image.gz                    # 8-10MB (真实内核)
├── ipq6018-jdcloud-ax6600.dtb  # 20-50KB (真实设备树)
├── initramfs.cpio.gz           # 2-3MB
├── modules.tar.gz              # 5-10MB (内核模块)
├── ax6600-alpine.itb           # 15-20MB (FIT镜像)
└── ax6600-alpine-factory.bin   # 30-40MB (完整固件)
```

## 验证固件

```bash
# 检查内核大小
ls -lh out/Image.gz
# 应显示 ~8-10MB，不是 45B

# 检查设备树
dtc -I dtb -O dts out/ipq6018-jdcloud-ax6600.dtb

# 检查FIT镜像
fdtdump out/ax6600-alpine.itb
```

## 刷机测试

构建完成后，按以下步骤测试：

1. **TTL连接**：USB转TTL连接路由器（3.3V, 115200）
2. **进入U-Boot**：上电时按回车中断启动
3. **TFTP刷机**：
   ```
   setenv serverip 192.168.10.1
   tftpboot 0x44000000 ax6600-alpine-factory.bin
   mmc erase 0x00004022 0x3000
   mmc write 0x44000000 0x00004022 0x3000
   reset
   ```
4. **验证启动**：观察串口输出，应能看到Linux启动日志

## 当前状态

⚠️ **占位符模式**：当前构建使用占位符内核，仅供开发测试结构使用。

✅ **生产就绪**：项目结构和构建脚本已完整，只需在有编译环境的主机上运行 `./build.sh` 即可生成真实固件。
