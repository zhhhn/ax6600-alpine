#!/bin/sh
# ClawUI Network API
# Network interface configuration

# Read POST body
read_post() {
    if [ "$REQUEST_METHOD" = "POST" ]; then
        read -n $CONTENT_LENGTH POST_DATA
        echo "$POST_DATA"
    fi
}

# Get network config
get_network_config() {
    local lan_ip=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    local lan_mask=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f2)
    local wan_ip=$(ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    local wan_proto="dhcp"
    
    # Check for PPPoE
    if [ -f /etc/ppp/peers/pppoe ]; then
        wan_proto="pppoe"
        wan_ip=$(ip addr show ppp0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    fi
    
    cat << EOF
{
    "lan": {
        "ip": "${lan_ip:-192.168.1.1}",
        "mask": "${lan_mask:-24}",
        "interface": "br-lan"
    },
    "wan": {
        "ip": "${wan_ip:-}",
        "proto": "$wan_proto",
        "interface": "eth0"
    },
    "interfaces": [
        {"name": "eth0", "type": "wan", "status": "$(ip link show eth0 2>/dev/null | grep -q UP && echo 'up' || echo 'down')"},
        {"name": "br-lan", "type": "lan", "status": "$(ip link show br-lan 2>/dev/null | grep -q UP && echo 'up' || echo 'down')"},
        {"name": "eth1", "type": "lan-port", "status": "$(ip link show eth1 2>/dev/null | grep -q UP && echo 'up' || echo 'down')"},
        {"name": "eth2", "type": "lan-port", "status": "$(ip link show eth2 2>/dev/null | grep -q UP && echo 'up' || echo 'down')"},
        {"name": "eth3", "type": "lan-port", "status": "$(ip link show eth3 2>/dev/null | grep -q UP && echo 'up' || echo 'down')"},
        {"name": "eth4", "type": "lan-port", "status": "$(ip link show eth4 2>/dev/null | grep -q UP && echo 'up' || echo 'down')"}
    ]
}
EOF
}

# Update network config
update_network_config() {
    local data=$(read_post)
    
    # Parse JSON (simplified)
    local lan_ip=$(echo "$data" | grep -o '"lan_ip":"[^"]*"' | cut -d'"' -f4)
    local wan_proto=$(echo "$data" | grep -o '"wan_proto":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$lan_ip" ]; then
        # Update LAN IP
        sed -i "s/address.*/address $lan_ip/" /etc/network/interfaces
        echo '{"success": true, "message": "Network config updated"}'
    else
        echo '{"success": false, "message": "No changes"}'
    fi
}

# Get interface details
get_interface() {
    local iface=$(echo "$QUERY_STRING" | grep -o 'iface=[^&]*' | cut -d= -f2)
    
    if [ -n "$iface" ]; then
        local ip=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}')
        local mac=$(ip link show "$iface" 2>/dev/null | grep ether | awk '{print $2}')
        local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        
        cat << EOF
{
    "name": "$iface",
    "ip": "${ip:-}",
    "mac": "${mac:-}",
    "rx_bytes": $rx,
    "tx_bytes": $tx
}
EOF
    else
        get_network_config
    fi
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        get_interface
        ;;
    POST)
        update_network_config
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac