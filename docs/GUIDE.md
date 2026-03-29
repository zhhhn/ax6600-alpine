# 使用指南

> 固件构建与刷机完整指南

---

## 第一部分：构建固件

### 环境要求

| 资源 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 系统 | Ubuntu 20.04 | Ubuntu 22.04 LTS |
| CPU | 2 核 | 4 核+ |
| 内存 | 4GB | 8GB+ |
| 磁盘 | 20GB | 50GB+ |

### 安装依赖

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential flex bison libncurses-dev libssl-dev bc \
    u-boot-tools wget git cpio gzip tar \
    gcc-aarch64-linux-gnu \
    qemu-user-static qemu-system-arm
```

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
├── alpine-rootfs.tar.gz        # 根文件系统 (33MB)
├── modules.tar.gz              # 内核模块 (69MB)
└── SHA256SUMS                  # 校验和
```

### 分步构建

```bash
# 只构建内核
./scripts/build-kernel.sh all

# 只构建 rootfs
./scripts/build-rootfs.sh

# 只打包固件
./scripts/package-firmware.sh
```

### GitHub Actions 自动构建

推送到 main 分支自动触发构建，在 Actions 页面下载产物。

---

## 第二部分：刷入设备

### ⚠️ 重要提示

- **刷机有风险**，可能导致设备变砖
- **失去保修**，刷机后不再享受官方保修
- **备份 ART**，请备份 WiFi 校准数据分区

### 准备工作

| 工具 | 说明 |
|------|------|
| TTL 串口线 | 3.3V 电平，CH340 或 FT232 |
| TFTP 服务器 | 用于传输固件 |
| 网线 | 连接电脑和路由器 |

### 方法一：U-Boot TFTP 刷写（推荐）

#### 步骤 1：连接串口

1. 拆开路由器
2. 找到 TTL 串口位置
3. 连接串口线：
   ```
   路由器 TX → USB-TTL RX
   路由器 RX → USB-TTL TX
   路由器 GND → USB-TTL GND
   ```
4. 打开串口终端：
   ```bash
   screen /dev/ttyUSB0 115200
   ```

#### 步骤 2：进入 U-Boot

1. 给路由器上电
2. 看到启动信息时快速按任意键
3. 进入 `=> ` 提示符

#### 步骤 3：配置网络

```bash
# 在 U-Boot 控制台执行
setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10

# 测试连接
ping ${serverip}
```

#### 步骤 4：刷写固件

```bash
# 加载固件到内存
tftpboot 0x44000000 ax6600-alpine-factory.bin

# 擦除并写入
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000

# 重启
reset
```

### 方法二：U-Boot Web UI

1. 断电，按住 Reset 按钮
2. 上电，保持按住 10 秒
3. 蓝灯亮起后松开
4. 浏览器打开 `http://192.168.1.1`
5. 上传固件文件

### 方法三：系统内升级

```bash
# 已运行 Alpine 系统时
sysupgrade ax6600-alpine-factory.bin
```

---

## 第三部分：验证安装

### 首次登录

```
Web UI:  http://192.168.1.1
SSH:     ssh root@192.168.1.1
密码:    空（直接回车）
WiFi:    AX6600 / admin123
```

### 检查系统

```bash
# 查看系统信息
uname -a
cat /etc/alpine-release

# 检查网络
ip addr
ping 8.8.8.8

# 检查 WiFi
wifi status
```

---

## 常见问题

### 构建问题

**Q: 内核编译失败**
```bash
# 安装所有依赖
sudo apt-get install -y build-essential flex bison libssl-dev
```

**Q: 交叉编译器找不到**
```bash
sudo apt-get install -y gcc-aarch64-linux-gnu
```

### 刷机问题

**Q: 无法进入 U-Boot**
- 检查串口连接
- 尝试不同的按键时机
- 确认波特率为 115200

**Q: TFTP 传输失败**
- 检查网络连接和防火墙
- 确认 TFTP 服务器运行

**Q: 刷写后无法启动**
- 重新刷写
- 检查固件完整性

---

## 分区布局

```
eMMC (mmcblk0)
├── mmcblk0p11  HLOS (内核)     6MB
├── mmcblk0p18  rootfs         512MB+
└── mmcblk0p27  数据分区       剩余空间
```

---

## ART 分区备份

WiFi 校准数据必须备份：

```bash
# 在 U-Boot 中备份
mmc read 0x44000000 0x00004000 0x100
tftpboot ${fileaddr} art_backup.bin

# 在 Linux 中备份
dd if=/dev/mmcblk0p7 of=/tmp/art.bin
```

---

相关文档：
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南
- [APPS.md](APPS.md) - 应用列表
- [ARCHITECTURE.md](ARCHITECTURE.md) - 系统架构