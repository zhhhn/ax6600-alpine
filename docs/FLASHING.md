# 刷机指南

本文档说明如何将固件刷入京东云 AX6600 路由器。

## ⚠️ 重要提示

- **刷机有风险**，可能导致设备变砖
- **失去保修**，刷机后不再享受官方保修
- **备份 ART**，请备份 WiFi 校准数据分区
- **准备救砖**，确保有 TTL 串口线和救砖方案

## 准备工作

### 必需工具

| 工具 | 说明 |
|------|------|
| TTL 串口线 | 3.3V 电平，推荐 CH340 或 FT232 |
| TFTP 服务器 | 用于传输固件 |
| 网线 | 连接电脑和路由器 |
| 拆机工具 | 螺丝刀、撬棒 |

### 文件准备

从 [Releases](https://github.com/zhhhn/ax6600-alpine/releases) 下载：
- `ax6600-alpine-factory.bin` - 完整刷机包
- `SHA256SUMS` - 校验文件

### 网络配置

```bash
# 设置电脑 IP
sudo ip addr add 192.168.10.1/24 dev eth0

# 启动 TFTP 服务器
sudo apt-get install tftpd-hpa
sudo cp ax6600-alpine-factory.bin /var/lib/tftpboot/
```

## 方法一：U-Boot TFTP 刷写 (推荐)

### 步骤 1：连接串口

1. 拆开路由器
2. 找到 TTL 串口 (通常在主板边缘)
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

### 步骤 2：进入 U-Boot

1. 给路由器上电
2. 看到启动信息时快速按任意键
3. 进入 `=> ` 提示符

### 步骤 3：配置网络

```bash
# 在 U-Boot 控制台执行
setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10

# 测试连接
ping ${serverip}
```

### 步骤 4：刷写固件

```bash
# 加载固件到内存
tftpboot 0x44000000 ax6600-alpine-factory.bin

# 擦除并写入
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000

# 重启
reset
```

### 步骤 5：验证

启动后检查：
```bash
# 串口输出
Alpine Linux 3.19
JDCloud AX6600

# 登录
login: root
password: (空，直接回车)

# 检查系统
uname -a
cat /etc/alpine-release
```

## 方法二：U-Boot Web UI

### 步骤 1：进入恢复模式

1. 断电
2. 按住 Reset 按钮
3. 上电，保持按住 10 秒
4. 蓝灯亮起后松开

### 步骤 2：访问 Web UI

```
浏览器打开: http://192.168.1.1
```

### 步骤 3：上传固件

1. 选择固件文件
2. 点击上传
3. 等待刷写完成
4. 自动重启

## 方法三：已有系统升级

如果已经运行 Alpine 系统：

```bash
# 下载固件
wget https://github.com/.../ax6600-alpine-factory.bin

# 使用升级命令
sysupgrade ax6600-alpine-factory.bin

# 或使用安装命令
dd if=ax6600-alpine-factory.bin of=/dev/mmcblk0p18 bs=1M
reboot
```

## 分区布局

```
设备: mmcblk0 (eMMC)

分区布局:
mmcblk0p11  (HLOS)      - 内核分区 (6MB)
mmcblk0p18  (rootfs)    - 根文件系统 (512MB+)
mmcblk0p27  (数据)       - 用户数据分区
```

## ART 分区备份

WiFi 校准数据在 ART 分区，务必备份：

```bash
# 在 U-Boot 中备份
tftpboot ${loadaddr} art.bin
mmc read ${loadaddr} 0x00004000 0x100

# 在 Linux 中备份
dd if=/dev/mmcblk0p7 of=/tmp/art.bin
# 保存到安全位置
```

## 救砖方案

### 方案 1：U-Boot 重刷

如果 U-Boot 还能进入，重新按照步骤刷写。

### 方案 2：编程器救砖

1. 拆下 eMMC 芯片
2. 使用编程器写入备份
3. 重新焊接

### 方案 3：官方恢复

联系官方售后恢复（需要付费）。

## 常见问题

### Q: 无法进入 U-Boot

A: 
- 检查串口连接
- 尝试不同的按键时机
- 检查波特率是否为 115200

### Q: TFTP 传输失败

A:
- 检查网络连接
- 确认 TFTP 服务器运行
- 检查防火墙设置
- 尝试使用不同 IP 段

### Q: 刷写后无法启动

A:
- 重新刷写
- 检查固件完整性
- 确认分区正确
- 检查电源稳定性

### Q: WiFi 不工作

A:
- 检查 ART 分区是否完整
- 确认 ath11k 驱动加载
- 检查设备树配置

## 刷机命令参考

```bash
# U-Boot 完整命令序列
setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10
ping ${serverip}
tftpboot 0x44000000 ax6600-alpine-factory.bin
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000
reset

# 备份 ART 分区
mmc read 0x44000000 0x00004000 0x100
tftpboot ${fileaddr} art_backup.bin

# 恢复 ART 分区
tftpboot 0x44000000 art_backup.bin
mmc write 0x44000000 0x00004000 0x100
```

---

相关文档：
- [BUILD.md](BUILD.md) - 构建固件
- [ARCHITECTURE.md](ARCHITECTURE.md) - 分区布局