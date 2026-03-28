# Alpine Linux 移植检查清单

## 阶段追踪

### ✅ 阶段0: 项目准备 (2026-03-27)
- [x] 创建项目结构
- [x] 收集硬件信息
- [x] 研究现有OpenWrt移植
- [x] 确认内核支持状态
- [x] 创建设备树 (DTS)
- [x] 创建构建脚本

### ✅ 阶段1: 硬件准备与串口调试 (已完成)
- [x] 硬件信息收集完成 (基于OpenWrt源码分析)
- [x] 分析分区表结构
- [x] 研究启动流程
- [x] 获取root权限方法

### ✅ 阶段2: 启动环境分析 (已完成)
- [x] 分析U-Boot配置
- [x] 研究FIT镜像格式
- [x] 准备启动脚本

### ✅ 阶段3: 内核编译与适配 (脚本已完成)
- [x] 创建内核配置脚本
- [x] 配置IPQ60xx支持
- [x] 创建设备树

### 🔄 阶段4: Alpine根文件系统 (进行中)
- [x] 创建rootfs构建脚本
- [ ] 完整配置网络
- [ ] 配置路由服务

### ⏳ 阶段5: 路由功能实现
- [ ] dnsmasq (DHCP/DNS)
- [ ] hostapd (WiFi AP)
- [ ] nftables (防火墙)
- [ ] NAT转发

### ⏳ 阶段6: WiFi驱动集成
- [ ] QCN5022/QCN5052驱动
- [ ] 无线功能测试
- [ ] 性能优化

### ⏳ 阶段7: 系统完善
- [ ] Web管理界面
- [ ] 自动启动配置
- [ ] 系统更新机制

### ⏳ 阶段8: 收尾与文档
- [ ] 完整测试
- [ ] 编写安装指南
- [ ] 备份方案验证

**待用户执行**:
1. 拆机连接TTL串口
2. 获取启动日志
3. 备份ART和U-Boot分区

### ⏳ 阶段2: 启动环境分析
- [ ] 分析U-Boot配置
- [ ] 测试网络引导
- [ ] 准备Alpine内核
- [ ] 测试从网络启动

### ⏳ 阶段3: 内核编译与适配
- [ ] 配置Linux内核
- [ ] 设备树调整
- [ ] 编译并测试启动

### ⏳ 阶段4: Alpine根文件系统
- [ ] 创建arm64根文件系统
- [ ] 配置网络接口
- [ ] 存储分区规划

### ⏳ 阶段5: 路由功能实现
- [ ] dnsmasq (DHCP/DNS)
- [ ] hostapd (WiFi AP)
- [ ] nftables (防火墙)
- [ ] NAT转发

### ⏳ 阶段6: WiFi驱动集成
- [ ] QCN5022/QCN5052驱动
- [ ] 无线功能测试
- [ ] 性能优化

### ⏳ 阶段7: 系统完善
- [ ] Web管理界面
- [ ] 自动启动配置
- [ ] 系统更新机制

### ⏳ 阶段8: 收尾与文档
- [ ] 完整测试
- [ ] 编写安装指南
- [ ] 备份方案验证

---

## 关键技术点

### 内核版本
- **目标**: Linux 6.6 LTS
- **最低要求**: 5.10+ (IPQ6018支持已upstream)
- **源码**: https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

### Alpine版本
- **架构**: aarch64 (arm64)
- **版本**: 3.19+ (最新稳定版)
- **镜像**: https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/

### 分区规划 (目标)
```
/dev/mmcblk0p18 (rootfs): 512MB → 扩展至 1GB
/dev/mmcblk0p16 (HLOS): 6MB - 存放内核
新分区: 存放Alpine rootfs
```

### 启动流程
1. SBL1 → QSEE → APPSBL (U-Boot)
2. U-Boot加载内核和设备树
3. 内核启动，挂载rootfs
4. Alpine init系统接管

---

## 风险与应对

### 高风险
1. **ART分区丢失** → WiFi永久损坏
   - 应对：第一时间备份，多重备份

2. **eMMC变砖** → 需要9008救砖
   - 应对：保留原厂U-Boot，准备USB救砖工具

3. **WiFi驱动不兼容** → 无法使用无线
   - 应对：准备外部USB WiFi作为备选

### 中风险
1. **NSS加速不可用** → 性能下降
   - 应对：使用软件转发，接受性能损失

2. **启动参数错误** → 无法启动
   - 应对：保持TTL连接，随时调试

---

## 参考资源

### 文档
- [京东云AX6600刷机教程](https://github.com/lgs2007m/Actions-OpenWrt/blob/main/Tutorial/JDCloud-AX1800-Pro_AX6600-Athena.md)
- [IPQ6018内核支持](https://patchwork.kernel.org/cover/11762809/)
- [Alpine ARM64端口](https://wiki.alpinelinux.org/wiki/Release_Notes_for_Alpine_3.19.0)

### 工具
- U-Boot: https://github.com/lgs2007m/Actions-OpenWrt/releases
- 内核编译: cross-compile toolchain (aarch64-linux-gnu)
- 串口工具: screen, minicom, PuTTY

---

*最后更新：2026-03-27 21:36*
