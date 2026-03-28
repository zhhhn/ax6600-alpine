#!/bin/sh
# WiFi configuration page

echo "Content-Type: text/html"
echo ""

# Handle WiFi toggle
if [ -n "$QUERY_STRING" ] && echo "$QUERY_STRING" | grep -q "toggle=1"; then
    if pgrep -f hostapd > /dev/null; then
        /usr/sbin/wifi down
    else
        /usr/sbin/wifi up
    fi
    echo "Status: 302 Found"
    echo "Location: /cgi-bin/wifi.cgi"
    echo ""
    exit 0
fi

# Handle form submission
if [ "$REQUEST_METHOD" = "POST" ]; then
    read -n $CONTENT_LENGTH POST_DATA
    
    SSID_2G=$(echo "$POST_DATA" | grep -o 'ssid_2g=[^&]*' | cut -d= -f2 | tr -d '+')
    PASS_2G=$(echo "$POST_DATA" | grep -o 'pass_2g=[^&]*' | cut -d= -f2 | tr -d '+')
    SSID_5G=$(echo "$POST_DATA" | grep -o 'ssid_5g=[^&]*' | cut -d= -f2 | tr -d '+')
    PASS_5G=$(echo "$POST_DATA" | grep -o 'pass_5g=[^&]*' | cut -d= -f2 | tr -d '+')
    
    # Update configs
    [ -n "$SSID_2G" ] && sed -i "s/^ssid=.*/ssid=$SSID_2G/" /etc/hostapd/hostapd.conf
    [ -n "$PASS_2G" ] && sed -i "s/^wpa_passphrase=.*/wpa_passphrase=$PASS_2G/" /etc/hostapd/hostapd.conf
    [ -n "$SSID_5G" ] && sed -i "s/^ssid=.*/ssid=$SSID_5G/" /etc/hostapd/hostapd-5g.conf
    [ -n "$PASS_5G" ] && sed -i "s/^wpa_passphrase=.*/wpa_passphrase=$PASS_5G/" /etc/hostapd/hostapd-5g.conf
    
    # Restart WiFi
    /usr/sbin/wifi restart 2>/dev/null &
fi

# Get current config
SSID_2G=$(grep '^ssid=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
PASS_2G=$(grep '^wpa_passphrase=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
SSID_5G=$(grep '^ssid=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2)
PASS_5G=$(grep '^wpa_passphrase=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2)

# WiFi status
WIFI_STATUS="关闭"
if pgrep -f hostapd > /dev/null; then
    WIFI_STATUS="开启"
fi

cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>WiFi 设置 - AX6600</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <header><h1>📶 WiFi 设置</h1></header>
        <nav class="nav">
            <a href="/">状态</a>
            <a href="/cgi-bin/network.cgi">网络</a>
            <a href="/cgi-bin/wifi.cgi" class="active">WiFi</a>
            <a href="/cgi-bin/system.cgi">系统</a>
        </nav>
        
        <div class="card">
            <h2>WiFi 状态: $WIFI_STATUS</h2>
            <a href="/cgi-bin/wifi.cgi?toggle=1" class="btn">$([ "$WIFI_STATUS" = "开启" ] && echo "关闭 WiFi" || echo "开启 WiFi")</a>
        </div>
        
        <form method="post" class="card">
            <h2>2.4GHz 设置</h2>
            <div class="form-group">
                <label>网络名称 (SSID)</label>
                <input type="text" name="ssid_2g" value="$SSID_2G" placeholder="WiFi名称">
            </div>
            <div class="form-group">
                <label>密码</label>
                <input type="password" name="pass_2g" value="$PASS_2G" placeholder="至少8位密码">
            </div>
            
            <h2>5GHz 设置</h2>
            <div class="form-group">
                <label>网络名称 (SSID)</label>
                <input type="text" name="ssid_5g" value="$SSID_5G" placeholder="WiFi名称">
            </div>
            <div class="form-group">
                <label>密码</label>
                <input type="password" name="pass_5g" value="$PASS_5G" placeholder="至少8位密码">
            </div>
            
            <button type="submit" class="btn">保存设置</button>
        </form>
    </div>
</body>
</html>
EOF