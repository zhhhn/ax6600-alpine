# 自动开发配置

## Cron 定时任务设置

### 方法1: 使用系统 cron (推荐)

```bash
# 编辑 crontab
crontab -e

# 添加以下行（每10分钟运行一次）
*/10 * * * * /home/node/.openclaw/workspace/projects/ax6600-alpine/auto-dev.sh >> /home/node/.openclaw/workspace/projects/ax6600-alpine/logs/cron.log 2>&1
```

### 方法2: 使用 OpenClaw Cron (需要网关配置)

```bash
# 检查网关状态
openclaw gateway status

# 如果网关未运行，启动它
openclaw gateway start

# 然后配置 cron 任务
```

### 方法3: 手动运行

```bash
# 在项目目录中
./auto-dev.sh
```

## 自动开发脚本功能

`auto-dev.sh` 会：
1. 检查内核是否已编译
2. 检查 rootfs 是否已构建
3. 检查固件是否已打包
4. 自动执行缺失的步骤
5. 记录日志到 `logs/auto-dev.log`

## 日志查看

```bash
# 查看自动开发日志
tail -f projects/ax6600-alpine/logs/auto-dev.log

# 查看 cron 日志
tail -f projects/ax6600-alpine/logs/cron.log
```

## 项目状态检查

```bash
# 快速检查项目状态
cd projects/ax6600-alpine
ls -la out/
```

## 预期输出文件

构建完成后应存在：
- `out/Image.gz` - 内核镜像
- `out/ipq6018-jdcloud-ax6600.dtb` - 设备树
- `out/alpine-rootfs.tar.gz` - 根文件系统
- `out/ax6600-alpine.itb` - FIT 镜像
- `out/ax6600-alpine-factory.bin` - 可刷写固件

---

**注意**: 自动构建需要交叉编译工具链 `aarch64-linux-gnu-gcc` 已安装。
