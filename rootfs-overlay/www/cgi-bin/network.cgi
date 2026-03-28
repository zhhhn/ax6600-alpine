#!/bin/sh
# Network configuration page

echo "Content-Type: text/html"
echo ""

# Handle form submission
if [ "$REQUEST_METHOD" = "POST" ]; then
    read -n $CONTENT_LENGTH POST_DATA
    
    # Parse POST data
    LAN_IP=$(echo "$POST_DATA" | grep -o 'lan_ip=[^&]*' | cut -d= -f2 | urldecode)
    WAN_TYPE=$(echo "$POST_DATA" | grep -o 'wan_type=[^&]*' | cut -d= -f2 | urldecode)
    
    # Update network config
    if [ -n "$LAN_IP" ]; then
        sed -i "s/address.*/address $LAN_IP/" /etc/network/interfaces
        echo "<p>LAN IP 已更新为 $LAN_IP</p>"
    fi
    
    if [ "$WAN_TYPE" = "pppoe" ]; then
        PPPOE_USER=$(echo "$POST_DATA" | grep -o 'pppoe_user=[^&]*' | cut -d= -f2 | urldecode)
        PPPOE_PASS=$(echo "$POST_DATA" | grep -o 'pppoe_pass=[^&]*' | cut -d= -f2 | urldecode)
        /usr/sbin/pppoe-setup config "$PPPOE_USER" "$PPPOE_PASS"
    fi
fi

# Get current config
LAN_IP=$(grep "address" /etc/network/interfaces | head -1 | awk '{print $2}')
WAN_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
WAN_TYPE="dhcp"
[ -f /etc/ppp/peers/pppoe ] && WAN_TYPE="pppoe"

cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>网络设置 - AX6600</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <header><h1>🌐 网络设置</h1></header>
        <nav class="nav">
            <a href="/">状态</a>
            <a href="/cgi-bin/network.cgi" class="active">网络</a>
            <a href="/cgi-bin/wifi.cgi">WiFi</a>
            <a href="/cgi-bin/system.cgi">系统</a>
        </nav>
        
        <form method="post" class="card">
            <h2>LAN 设置</h2>
            <div class="form-group">
                <label>LAN IP 地址</label>
                <input type="text" name="lan_ip" value="$LAN_IP" placeholder="192.168.1.1">
            </div>
            <div class="form-group">
                <label>子网掩码</label>
                <input type="text" value="255.255.255.0" disabled>
            </div>
            
            <h2>WAN 设置</h2>
            <div class="form-group">
                <label>连接类型</label>
                <select name="wan_type" id="wan_type" onchange="togglePppoe()">
                    <option value="dhcp" $([ "$WAN_TYPE" = "dhcp" ] && echo selected)>DHCP (自动)</option>
                    <option value="static">静态 IP</option>
                    <option value="pppoe" $([ "$WAN_TYPE" = "pppoe" ] && echo selected)>PPPoE 拨号</option>
                </select>
            </div>
            
            <div id="pppoe_fields" style="display: $([ "$WAN_TYPE" = "pppoe" ] && echo block || echo none)">
                <div class="form-group">
                    <label>PPPoE 用户名</label>
                    <input type="text" name="pppoe_user" placeholder="宽带账号">
                </div>
                <div class="form-group">
                    <label>PPPoE 密码</label>
                    <input type="password" name="pppoe_pass" placeholder="宽带密码">
                </div>
            </div>
            
            <button type="submit" class="btn">保存设置</button>
        </form>
        
        <div class="card">
            <h2>当前状态</h2>
            <div class="stat">
                <span>WAN IP:</span>
                <span>${WAN_IP:-未连接}</span>
            </div>
            <div class="stat">
                <span>LAN IP:</span>
                <span>$LAN_IP</span>
            </div>
        </div>
    </div>
    <script>
        function togglePppoe() {
            const type = document.getElementById('wan_type').value;
            document.getElementById('pppoe_fields').style.display = type === 'pppoe' ? 'block' : 'none';
        }
    </script>
</body>
</html>
EOF