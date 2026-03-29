#!/bin/sh
# ClawUI PPPoE App API
# PPPoE dial-up configuration

PPPD="/usr/sbin/pppd"
PPPOE="/usr/sbin/pppoe"
PEERS_DIR="/etc/ppp/peers"
PPP_OPTIONS="/etc/ppp/options"
PPPOE_PEER="$PEERS_DIR/pppoe"
SECRETS="/etc/ppp/pap-secrets"
CHAP_SECRETS="/etc/ppp/chap-secrets"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Get PPPoE status
get_status() {
    local enabled="false"
    local running="false"
    local connected="false"
    local interface=""
    local ip=""
    local uptime=""
    local error=""
    
    # Check if pppd is installed
    if [ -x "$PPPD" ]; then
        # Check if ppp0 interface exists
        if ip link show ppp0 &>/dev/null; then
            connected="true"
            running="true"
            interface="ppp0"
            ip=$(ip addr show ppp0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
            uptime=$(ps -o etime= -p $(cat /var/run/ppp0.pid 2>/dev/null) 2>/dev/null | tr -d ' ')
        fi
        
        # Check if service is enabled
        if rc-service pppoe status 2>/dev/null | grep -q started; then
            enabled="true"
        fi
    fi
    
    # Get last error from log
    error=$(tail -20 /var/log/messages 2>/dev/null | grep -i pppd | tail -1 | cut -d']' -f2- | sed 's/^ //')
    
    cat << EOF
{
    "installed": $([ -x "$PPPD" ] && echo 'true' || echo 'false'),
    "enabled": $enabled,
    "running": $running,
    "connected": $connected,
    "interface": "$interface",
    "ip": "$ip",
    "uptime": "$uptime",
    "error": "$(echo "$error" | sed 's/"/\\"/g')"
}
EOF
}

# Get configuration
get_config() {
    local username=""
    local password=""
    local interface="eth0"
    local mtu="1492"
    local mru="1492"
    local default_route="true"
    local use_peerdns="true"
    local keepalive="true"
    
    # Read from existing config
    if [ -f "$PPPOE_PEER" ]; then
        username=$(grep "^user" "$PPPOE_PEER" 2>/dev/null | awk '{print $2}' | tr -d '"')
        interface=$(grep "^nic-" "$PPPOE_PEER" 2>/dev/null | sed 's/nic-//')
        mtu=$(grep "^mtu" "$PPPOE_PEER" 2>/dev/null | awk '{print $2}')
        mru=$(grep "^mru" "$PPPOE_PEER" 2>/dev/null | awk '{print $2}')
        
        grep -q "defaultroute" "$PPPOE_PEER" && default_route="true" || default_route="false"
        grep -q "usepeerdns" "$PPPOE_PEER" && use_peerdns="true" || use_peerdns="false"
        grep -q "persist" "$PPPOE_PEER" && keepalive="true" || keepalive="false"
    fi
    
    # Read password from secrets
    if [ -f "$SECRETS" ]; then
        password=$(grep "^$username" "$SECRETS" 2>/dev/null | awk '{print $3}')
    fi
    
    # Get available WAN interfaces
    local wan_interfaces=$(ip link show 2>/dev/null | grep -E 'eth[0-9]|enp' | awk -F: '{print $2}' | sed 's/ //g' | jq -R -s 'split("\n") | map(select(length > 0))')
    
    cat << EOF
{
    "username": "$username",
    "password": "$password",
    "interface": "${interface:-eth0}",
    "mtu": ${mtu:-1492},
    "mru": ${mru:-1492},
    "default_route": $default_route,
    "use_peerdns": $use_peerdns,
    "keepalive": $keepalive,
    "wan_interfaces": $wan_interfaces
}
EOF
}

# Save configuration
save_config() {
    read -n $CONTENT_LENGTH data
    
    local username=$(echo "$data" | jq -r '.username')
    local password=$(echo "$data" | jq -r '.password')
    local interface=$(echo "$data" | jq -r '.interface // "eth0"')
    local mtu=$(echo "$data" | jq -r '.mtu // 1492')
    local mru=$(echo "$data" | jq -r '.mru // 1492')
    local default_route=$(echo "$data" | jq -r '.default_route // true')
    local use_peerdns=$(echo "$data" | jq -r '.use_peerdns // true')
    local keepalive=$(echo "$data" | jq -r '.keepalive // true')
    local auto_connect=$(echo "$data" | jq -r '.auto_connect // false')
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo '{"success": false, "message": "用户名和密码不能为空"}'
        return 1
    fi
    
    # Create peers directory
    mkdir -p "$PEERS_DIR"
    
    # Write PPPoE peer config
    cat > "$PPPOE_PEER" << EOF
# ClawUI PPPoE Configuration
user "$username"
plugin rp-pppoe.so
nic-$interface
noauth
EOF

    [ "$default_route" = "true" ] && echo "defaultroute" >> "$PPPOE_PEER"
    [ "$use_peerdns" = "true" ] && echo "usepeerdns" >> "$PPPOE_PEER"
    [ "$keepalive" = "true" ] && echo "persist" >> "$PPPOE_PEER"
    
    echo "mtu $mtu" >> "$PPPOE_PEER"
    echo "mru $mru" >> "$PPPOE_PEER"
    
    # Add common options
    cat >> "$PPPOE_PEER" << EOF
noaccomp
default-asyncmap
nopcomp
receive-all
nodetach
ipparam pppoe
lcp-echo-interval 20
lcp-echo-failure 3
EOF

    chmod 600 "$PPPOE_PEER"
    
    # Save credentials
    echo "$username * $password *" > "$SECRETS"
    echo "$username * $password *" > "$CHAP_SECRETS"
    chmod 600 "$SECRETS" "$CHAP_SECRETS"
    
    # Enable service if auto_connect
    if [ "$auto_connect" = "true" ]; then
        rc-update add pppoe default 2>/dev/null
    fi
    
    echo '{"success": true, "message": "PPPoE 配置已保存"}'
}

# Connect PPPoE
connect() {
    # Stop any existing connection
    $PPPD call pppoe kill 2>/dev/null || true
    sleep 1
    
    # Start connection
    if $PPPD call pppoe updetach 2>&1 | head -20; then
        echo '{"success": true, "message": "PPPoE 已连接"}'
    else
        echo '{"success": false, "message": "PPPoE 连接失败，请检查用户名密码"}'
    fi
}

# Disconnect PPPoE
disconnect() {
    local pid=$(cat /var/run/ppp0.pid 2>/dev/null)
    
    if [ -n "$pid" ]; then
        kill $pid 2>/dev/null
        echo '{"success": true, "message": "PPPoE 已断开"}'
    else
        # Try to kill by interface
        $PPPD call pppoe kill 2>/dev/null
        echo '{"success": true, "message": "PPPoE 已断开"}'
    fi
}

# Get connection log
get_log() {
    local lines=$(echo "$QUERY_STRING" | grep -o 'lines=[0-9]*' | cut -d= -f2)
    lines=${lines:-50}
    
    local logs=$(tail -$lines /var/log/messages 2>/dev/null | grep -i ppp | jq -Rs '.')
    
    echo "{\"logs\": $logs}"
}

# Diagnose connection
diagnose() {
    local results="[]"
    local issues=""
    
    # Check if pppd is installed
    if [ ! -x "$PPPD" ]; then
        issues="PPPoE 软件未安装"
    fi
    
    # Check if interface exists
    local iface=$(grep "^nic-" "$PPPOE_PEER" 2>/dev/null | sed 's/nic-//')
    if [ -n "$iface" ] && ! ip link show "$iface" &>/dev/null; then
        issues="$issues, 网卡 $iface 不存在"
    fi
    
    # Check if carrier is detected
    if [ -n "$iface" ]; then
        local carrier=$(cat /sys/class/net/$iface/carrier 2>/dev/null)
        if [ "$carrier" != "1" ]; then
            issues="$issues, 网线未连接"
        fi
    fi
    
    # Check PPPoE server discovery
    if [ -x "$PPPOE" ] && [ -n "$iface" ]; then
        if ! $PPPOE -I $iface -A 2>&1 | grep -q "AC-Name"; then
            issues="$issues, 无法发现 PPPoE 服务器"
        fi
    fi
    
    # Check credentials
    if [ ! -f "$SECRETS" ] || [ ! -s "$SECRETS" ]; then
        issues="$issues, 未配置用户名密码"
    fi
    
    if [ -z "$issues" ]; then
        issues="未发现问题"
    fi
    
    cat << EOF
{
    "status": "$([ -z "$issues" ] && echo 'ok' || echo 'error')",
    "issues": "$issues",
    "checks": {
        "pppd_installed": $([ -x "$PPPD" ] && echo 'true' || echo 'false'),
        "interface_exists": $([ -n "$iface" ] && ip link show "$iface" &>/dev/null && echo 'true' || echo 'false'),
        "carrier_detected": $([ "$carrier" = "1" ] && echo 'true' || echo 'false'),
        "pppoe_server_found": $([ -x "$PPPOE" ] && $PPPOE -I $iface -A 2>&1 | grep -q "AC-Name" && echo 'true' || echo 'false'),
        "credentials_set": $([ -f "$SECRETS" ] && [ -s "$SECRETS" ] && echo 'true' || echo 'false')
    }
}
EOF
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/pppoe/config)
                get_config
                ;;
            /api/apps/pppoe/log)
                get_log
                ;;
            /api/apps/pppoe/diagnose)
                diagnose
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        case "$PATH_INFO" in
            /api/apps/pppoe/config)
                save_config
                ;;
            /api/apps/pppoe/connect)
                connect
                ;;
            /api/apps/pppoe/disconnect)
                disconnect
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac