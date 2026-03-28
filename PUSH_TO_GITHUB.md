# 推送到GitHub并开始自动构建

## 步骤1: 在GitHub创建仓库

1. 访问 https://github.com/new
2. 输入仓库名: `ax6600-alpine`
3. 选择 **Public** (或Private)
4. 不要初始化README (我们已有)
5. 点击 **Create repository**

## 步骤2: 推送代码

```bash
cd /home/node/.openclaw/workspace/projects/ax6600-alpine

# 初始化git (如果尚未初始化)
git init

# 添加远程仓库 (替换YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/ax6600-alpine.git

# 推送代码
git branch -M main
git push -u origin main
```

## 步骤3: 验证自动构建

1. 访问 `https://github.com/YOUR_USERNAME/ax6600-alpine/actions`
2. 应该看到 workflow 正在运行
3. 等待约15-30分钟构建完成

## 步骤4: 下载固件

构建完成后：

**方式1 - Releases页面**
```
https://github.com/YOUR_USERNAME/ax6600-alpine/releases
```

**方式2 - Actions Artifacts**
```
https://github.com/YOUR_USERNAME/ax6600-alpine/actions
→ 点击最新workflow → Artifacts
```

## 预期输出文件

```
ax6600-alpine-factory.bin    # 刷机固件 (30-40MB)
ax6600-alpine.itb            # FIT镜像
flash-commands.txt           # 刷机命令
install.sh                   # 安装脚本
SHA256SUMS                   # 校验和
```

## 故障排查

### 推送失败
```bash
# 检查远程仓库
git remote -v

# 如果已存在，先删除
git remote remove origin

# 重新添加
git remote add origin https://github.com/YOUR_USERNAME/ax6600-alpine.git
```

### 认证问题
使用HTTPS推送时需要输入GitHub用户名和密码：
- 用户名: GitHub用户名
- 密码: **Personal Access Token** (不是登录密码!)

创建Token: https://github.com/settings/tokens

或使用SSH：
```bash
git remote set-url origin git@github.com:YOUR_USERNAME/ax6600-alpine.git
```

### 构建失败
1. 查看Actions日志
2. 检查build.yml配置
3. 确保所有脚本有执行权限

## 快速命令

```bash
# 一键推送
git add .
git commit -m "Update firmware build"
git push origin main

# 查看状态
git status
git log --oneline -5
```

## 构建时间

| 步骤 | 预估时间 |
|------|---------|
| 安装依赖 | 2-3分钟 |
| 下载内核源码 | 1-2分钟 |
| 配置内核 | 1分钟 |
| 编译内核 | 15-20分钟 |
| 构建rootfs | 2-3分钟 |
| 打包固件 | 1分钟 |
| **总计** | **20-30分钟** |

## 下一步

1. ✅ 推送代码到GitHub
2. ⏳ 等待Actions构建完成
3. 📥 下载固件
4. 🔧 刷入路由器测试
