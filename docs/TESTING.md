# 测试与模拟环境

本文档描述固件的测试框架和虚拟环境。

## 测试框架

### 本地测试脚本

```bash
# 运行所有测试 (45项)
./scripts/test-firmware.sh all

# 快速冒烟测试
./scripts/test-firmware.sh smoke

# 按类别测试
./scripts/test-firmware.sh scripts    # 脚本测试
./scripts/test-firmware.sh init       # Init 脚本
./scripts/test-firmware.sh cgi        # CGI 脚本
./scripts/test-firmware.sh config     # 配置文件
```

### 测试覆盖

| 类别 | 测试数 | 说明 |
|------|--------|------|
| 用户脚本 | 9 | wifi, port-forward, qos 等 |
| Init 脚本 | 11 | leds, network, wifi 等 |
| CGI 脚本 | 7 | stats, network, wifi 等 |
| 配置文件 | 18 | 网络、WiFi、防火墙 |
| **总计** | **45** | |

### 测试内容

```
✅ 语法检查
✅ 函数定义
✅ 配置完整性
✅ API 响应格式
✅ 必要文件存在
```

## 虚拟环境

### 方式一：Python 模拟器

最轻量的测试方式：

```bash
# 启动模拟器
python3 scripts/simulate.py

# 访问
# Web UI: http://localhost:8080
# API: http://localhost:8080/api/*
```

**特点：**
- ⚡ 秒级启动
- 无需依赖
- 模拟 REST API
- 提供静态文件服务

**适用：**
- 前端开发
- API 测试
- 界面预览

### 方式二：Docker 路由器

完整用户空间模拟：

```bash
# 构建镜像
./scripts/router-sim.sh build

# 启动
./scripts/router-sim.sh start

# 访问
# Web UI: http://localhost:8080
# SSH: ssh root@localhost -p 2222
```

**特点：**
- 完整 Alpine 环境
- 真实服务运行
- 网络模拟
- 软件包安装测试

**适用：**
- 功能验证
- 服务测试
- 配置验证

### 方式三：QEMU 虚拟机

ARM64 完整模拟：

```bash
# 安装 QEMU
sudo apt-get install qemu-system-arm qemu-utils

# 创建虚拟机
./scripts/vm.sh create

# 启动
./scripts/vm.sh start

# 后台运行
./scripts/vm.sh start-daemon

# 刷入固件
./scripts/vm.sh flash out/ax6600-alpine-factory.bin
```

**特点：**
- 真实 ARM64 环境
- 可刷入固件
- 完整启动流程

**适用：**
- 固件测试
- 启动流程验证
- 内核调试

### 对比

| 方式 | 启动 | 真实性 | 依赖 |
|------|------|--------|------|
| Python | ⚡ 秒级 | 低 | Python |
| Docker | ⚡ 秒级 | 中 | Docker |
| QEMU | 🐢 分钟 | 高 | QEMU |

## 持续集成

### GitHub Actions

每次推送自动运行测试：

```yaml
# .github/workflows/build.yml
jobs:
  test:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/test-firmware.sh all
  
  build:
    needs: test
    runs-on: ubuntu-22.04
    steps:
      - run: ./build.sh
```

### 本地 CI

```bash
# 模拟 CI 流程
./scripts/test-firmware.sh all && ./build.sh
```

## 调试工具

### 串口调试

```bash
# 连接串口
screen /dev/ttyUSB0 115200

# 或使用 minicom
minicom -D /dev/ttyUSB0
```

### 日志查看

```bash
# 系统日志
tail -f /var/log/messages

# 服务日志
tail -f /var/log/firewall.log
```

### 网络调试

```bash
# 抓包
tcpdump -i eth0 -w capture.pcap

# 接口状态
ip link show
ip addr show
```

## 故障排除

### 测试失败

```bash
# 详细输出
bash -x scripts/test-firmware.sh all

# 单独测试
bash -n /usr/sbin/wifi
```

### 模拟器问题

```bash
# 端口占用
lsof -i :8080

# Python 错误
python3 scripts/simulate.py --debug
```

---

相关文档：
- [BUILD.md](BUILD.md) - 构建指南
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发指南