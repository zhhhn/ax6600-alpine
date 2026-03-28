#!/bin/sh
# Factory reset handler

echo "Content-Type: text/html"
echo ""

# Handle POST (confirm reset)
if [ "$REQUEST_METHOD" = "POST" ]; then
    # Execute factory reset
    /usr/sbin/factory-reset --backup &
    
    cat << EOF
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>恢复出厂设置</title></head>
<body style="background:#1a1a2e;color:#eee;font-family:sans-serif;text-align:center;padding:50px;">
    <h1>⚠️ 系统正在恢复出厂设置...</h1>
    <p>请稍候，系统将自动重启</p>
    <p>此过程大约需要 1-2 分钟</p>
</body>
</html>
EOF
    exit 0
fi

# Show confirmation page
cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>恢复出厂设置 - AX6600</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <header><h1>⚠️ 恢复出厂设置</h1></header>
        
        <div class="card" style="max-width:500px;margin:50px auto;">
            <h2>警告：此操作不可逆！</h2>
            <p>恢复出厂设置将清除以下内容：</p>
            <ul>
                <li>网络配置（WAN/LAN 设置）</li>
                <li>WiFi 配置（SSID 和密码）</li>
                <li>防火墙规则</li>
                <li>端口转发规则</li>
                <li>系统密码</li>
            </ul>
            <p>系统将自动备份当前配置。</p>
            
            <form method="post">
                <button type="submit" class="btn btn-danger" onclick="return confirm('确定要恢复出厂设置吗？此操作不可撤销！')">确认恢复出厂设置</button>
                <a href="/" class="btn">取消</a>
            </form>
        </div>
    </div>
</body>
</html>
EOF