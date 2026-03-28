#!/bin/sh
# Status API for AX6600 web UI

echo "Content-Type: application/json"
echo ""

# Get uptime
UPTIME=$(uptime | sed 's/.*up \([^,]*\),.*/\1/')

# Get CPU usage
CPU=$(top -bn1 | grep "CPU:" | sed 's/.*\([0-9]*\.[0-9]*\)% id.*/\1/' | awk '{print int(100 - $1)}')

# Get memory usage
MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
MEM_USED=$(free -m | grep Mem | awk '{print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

# Get WAN IP
WAN_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
[ -z "$WAN_IP" ] && WAN_IP="未连接"

# Get traffic (from /proc/net/dev)
WAN_RX=$(cat /proc/net/dev | grep eth0 | awk '{print $2}')
WAN_TX=$(cat /proc/net/dev | grep eth0 | awk '{print $10}')
# Convert to MB
DOWNLOAD=$((WAN_RX / 1024 / 1024))
UPLOAD=$((WAN_TX / 1024 / 1024))

# WiFi status
WIFI_2G="关闭"
WIFI_5G="关闭"
if pgrep -f "hostapd.*wlan0" > /dev/null; then
    WIFI_2G=$(grep '^ssid=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
    [ -z "$WIFI_2G" ] && WIFI_2G="开启"
fi
if pgrep -f "hostapd.*wlan1" > /dev/null; then
    WIFI_5G=$(grep '^ssid=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2)
    [ -z "$WIFI_5G" ] && WIFI_5G="开启"
fi

# Connected clients (from dnsmasq leases)
CLIENTS=0
DHCP_LIST="[]"
if [ -f /var/lib/misc/dnsmasq.leases ]; then
    CLIENTS=$(wc -l < /var/lib/misc/dnsmasq.leases)
    DHCP_LIST=$(awk '{printf "{\"ip\":\""$3"\",\"mac\":\""$2"\",\"hostname\":\""$4"\"},"}' /var/lib/misc/dnsmasq.leases | sed 's/,$//')
    [ -n "$DHCP_LIST" ] && DHCP_LIST="[$DHCP_LIST]"
fi

# Output JSON
cat << EOF
{
    "uptime": "$UPTIME",
    "cpu": $CPU,
    "memory": "${MEM_USED}MB / ${MEM_TOTAL}MB",
    "memory_percent": $MEM_PERCENT,
    "wan_ip": "$WAN_IP",
    "download": "${DOWNLOAD} MB",
    "upload": "${UPLOAD} MB",
    "wifi_2g": "$WIFI_2G",
    "wifi_5g": "$WIFI_5G",
    "clients": $CLIENTS,
    "dhcp_list": $DHCP_LIST
}
EOF