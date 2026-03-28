#!/bin/sh
# System configuration page

echo "Content-Type: text/html"
echo ""

# Handle actions
ACTION=$(echo "$QUERY_STRING" | grep -o 'action=[^&]*' | cut -d= -f2)

case "$ACTION" in
    reboot)
        echo "<p>系统正在重启...</p>"
        reboot &
        ;;
    backup)
        echo "Content-Type: application/octet-stream"
        echo "Content-Disposition: attachment; filename=config-backup.tar.gz"
        echo ""
        tar -czf - /etc/network/interfaces /etc/hostapd/*.conf /etc/dnsmasq.conf /etc/nftables.conf /etc/shadow 2>/dev/null
        exit 0
        ;;
    restore)
        # Handle file upload (simplified)
        echo "<p>配置恢复功能需要文件上传支持</p>"
        ;;
esac

# Get system info
KERNEL=$(uname -r)
UPTIME=$(uptime | sed 's/.*up \([^,]*\),.*/\1/')
MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
MEM_USED=$(free -m | grep Mem | awk '{print $3}')
DISK_TOTAL=$(df -h / | tail -1 | awk '{print $2}')
DISK_USED=$(df -h / | tail -1 | awk '{print $3}')

cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>系统设置 - AX6600</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <header><h1>⚙️ 系统设置</h1></header>
        <nav class="nav">
            <a href="/">状态</a>
            <a href="/cgi-bin/network.cgi">网络</a>
            <a href="/cgi-bin/wifi.cgi">WiFi</a>
            <a href="/cgi-bin/system.cgi" class="active">系统</a>
        </nav>
        
        <div class="card">
            <h2>系统信息</h2>
            <div class="stat"><span>内核版本:</span><span>$KERNEL</span></div>
            <div class="stat"><span>运行时间:</span><span>$UPTIME</span></div>
            <div class="stat"><span>内存使用:</span><span>${MEM_USED}MB / ${MEM_TOTAL}MB</span></div>
            <div class="stat"><span>磁盘使用:</span><span>${DISK_USED} / ${DISK_TOTAL}</span></div>
        </div>
        
        <div class="card">
            <h2>系统操作</h2>
            <a href="?action=reboot" class="btn btn-danger" onclick="return confirm('确定重启系统？')">🔄 重启系统</a>
            <a href="?action=backup" class="btn">💾 备份配置</a>
            <a href="/cgi-bin/factory-reset.cgi" class="btn btn-danger" onclick="return confirm('确定恢复出厂设置？这将清除所有配置！')">⚠️ 恢复出厂</a>
        </div>
        
        <div class="card">
            <h2>固件升级</h2>
            <form method="post" action="/cgi-bin/upgrade.cgi" enctype="multipart/form-data">
                <div class="form-group">
                    <label>选择固件文件</label>
                    <input type="file" name="firmware" accept=".bin,.tar.gz">
                </div>
                <label><input type="checkbox" name="keep_config" checked> 保留当前配置</label>
                <button type="submit" class="btn btn-danger" onclick="return confirm('确定升级固件？')">📤 升级固件</button>
            </form>
        </div>
        
        <div class="card">
            <h2>修改密码</h2>
            <form method="post" action="/cgi-bin/password.cgi">
                <div class="form-group">
                    <label>当前密码</label>
                    <input type="password" name="old_pass" placeholder="当前密码">
                </div>
                <div class="form-group">
                    <label>新密码</label>
                    <input type="password" name="new_pass" placeholder="新密码">
                </div>
                <div class="form-group">
                    <label>确认密码</label>
                    <input type="password" name="confirm_pass" placeholder="确认密码">
                </div>
                <button type="submit" class="btn">修改密码</button>
            </form>
        </div>
    </div>
</body>
</html>
EOF