# GitHub Setup Guide

## 快速开始

### 1. 创建GitHub仓库

```bash
# 在GitHub上创建新仓库，例如: ax6600-alpine
# 然后推送代码
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/ax6600-alpine.git
git push -u origin main
```

### 2. 自动构建

推送代码后，GitHub Actions会自动：
- 安装编译工具
- 编译ARM64内核
- 构建Alpine rootfs
- 打包固件
- 上传Artifacts
- 创建Release

### 3. 下载固件

构建完成后，在以下位置获取固件：

**方式1 - Releases页面**
- 访问: `https://github.com/YOUR_USERNAME/ax6600-alpine/releases`
- 下载最新版本的固件

**方式2 - Actions Artifacts**
- 访问: `https://github.com/YOUR_USERNAME/ax6600-alpine/actions`
- 点击最新workflow run
- 下载Artifacts

## 项目结构

```
ax6600-alpine/
├── .github/
│   └── workflows/
│       └── build.yml          # GitHub Actions配置
├── configs/
│   └── ipq6018-jdcloud-ax6600.dts  # 设备树
├── rootfs-overlay/            # rootfs自定义文件
├── scripts/
│   ├── build-kernel.sh        # 内核构建
│   ├── build-rootfs.sh        # rootfs构建
│   └── package-firmware.sh    # 固件打包
├── build.sh                   # 主构建脚本
└── README.md                  # 项目说明
```

## 自动构建流程

```
代码推送
    ↓
GitHub Actions触发
    ↓
安装依赖 (flex, bison, gcc-aarch64-linux-gnu)
    ↓
下载Linux 6.6.22源码
    ↓
配置内核 (IPQ60xx支持)
    ↓
编译内核 (Image.gz + dtb + modules)
    ↓
构建Alpine rootfs
    ↓
打包FIT镜像
    ↓
生成工厂固件 (factory.bin)
    ↓
上传Artifacts + 创建Release
```

## 配置说明

### 修改触发条件

编辑 `.github/workflows/build.yml`:

```yaml
on:
  push:
    branches: [ main ]      # 只在main分支推送时触发
    tags: [ 'v*' ]          # 或推送标签时触发
  schedule:
    - cron: '0 0 * * 0'     # 每周日自动构建
```

### 修改保留时间

Artifacts默认保留30天，可在workflow中修改：

```yaml
- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    retention-days: 90      # 改为90天
```

### 添加编译缓存

加速后续构建：

```yaml
- name: Cache kernel source
  uses: actions/cache@v3
  with:
    path: build/linux-6.6.22
    key: ${{ runner.os }}-kernel-6.6.22
```

## 本地测试

在推送前本地测试构建：

```bash
# 安装Docker
sudo docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ubuntu:22.04 \
  bash -c "
    apt-get update && \
    apt-get install -y build-essential flex bison gcc-aarch64-linux-gnu && \
    ./build.sh
  "
```

## 故障排查

### 构建失败

1. 查看Actions日志
2. 检查依赖安装步骤
3. 验证内核配置

### 固件无法启动

1. 检查设备树是否正确
2. 验证内核配置是否包含必要驱动
3. 确认分区地址正确

## 安全提示

⚠️ **刷机有风险**
- 备份ART分区（WiFi校准数据）
- 保留原厂固件备份
- 准备救砖工具

## 相关链接

- [GitHub Actions文档](https://docs.github.com/en/actions)
- [OpenWrt IPQ60xx](https://openwrt.org/toh/jdcloud/ax6600)
- [Alpine Linux](https://alpinelinux.org/)
- [Linux Kernel](https://kernel.org/)
