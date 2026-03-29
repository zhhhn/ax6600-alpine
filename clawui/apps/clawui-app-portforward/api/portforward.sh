#!/bin/sh
# ClawUI Port Forward App API
# Port forwarding, DMZ, and UPnP management

NFT="/usr/sbin/nft"
CONF_DIR="/etc/clawui/portforward"
FORWARD_CONF="$CONF_DIR/forwards.json"
DMZ_CONF="$CONF_DIR/dmz.json"
UPNP_CONF="$CONF_DIR/upnp.conf"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize config directory
init_config() {
    mkdir -p "$CONF_DIR"
    [ ! -f "$FORWARD_CONF" ] && echo '[]' > "$FORWARD_CONF"
    [ ! -f "$DMZ_CONF" ] && echo '{"enabled": false, "host": ""}' > "$DMZ_CONF"
}

# Get WAN interface
get_wan_iface() {
    # Try to detect WAN interface
    if ip link show ppp0 &>/dev/null; then
        echo "ppp0"
    elif ip link show eth0 &>/dev/null; then
        echo "eth0"
    else
        echo "eth0"
    fi
}

# Get LAN network
get_lan_network() {
    local lan_ip=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}')
    echo "${lan_ip:-192.168.1.1/24}"
}

# List all port forwards
list_forwards() {
    init_config
    cat "$FORWARD_CONF"
}

# Get a single forward rule
get_forward() {
    local id="$1"
    init_config
    
    local rule=$(cat "$FORWARD_CONF" | jq -r ".[] | select(.id == \"$id\")")
    if [ -n "$rule" ]; then
        echo "$rule"
    else
        echo '{"error": "Rule not found"}'
    fi
}

# Add port forward rule
add_forward() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local proto=$(echo "$data" | jq -r '.proto // "tcp"')
    local wan_port=$(echo "$data" | jq -r '.wan_port')
    local lan_ip=$(echo "$data" | jq -r '.lan_ip')
    local lan_port=$(echo "$data" | jq -r '.lan_port // .wan_port')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    
    # Validate
    if [ -z "$wan_port" ] || [ -z "$lan_ip" ]; then
        echo '{"success": false, "message": "端口和目标IP必填"}'
        return 1
    fi
    
    # Validate IP format
    if ! echo "$lan_ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo '{"success": false, "message": "无效的IP地址格式"}'
        return 1
    fi
    
    # Generate ID
    local id=$(echo "$proto-$wan_port-$lan_ip-$lan_port" | tr '.' '-' | tr ':' '-')
    
    # Check for duplicates
    if cat "$FORWARD_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "规则已存在"}'
        return 1
    fi
    
    # Add to config
    local new_rule=$(cat << EOF
{
    "id": "$id",
    "name": "${name:-$proto/$wan_port}",
    "proto": "$proto",
    "wan_port": "$wan_port",
    "lan_ip": "$lan_ip",
    "lan_port": "$lan_port",
    "enabled": $enabled,
    "created_at": "$(date -Iseconds)"
}
EOF
)
    
    local updated=$(cat "$FORWARD_CONF" | jq ". + [$new_rule]")
    echo "$updated" > "$FORWARD_CONF"
    
    # Apply rule if enabled
    if [ "$enabled" = "true" ]; then
        apply_forward "$id"
    fi
    
    echo "{\"success\": true, \"message\": \"端口转发规则已添加\", \"id\": \"$id\"}"
}

# Update forward rule
update_forward() {
    local id="$1"
    read -n $CONTENT_LENGTH data
    
    init_config
    
    # Check if rule exists
    if ! cat "$FORWARD_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "规则不存在"}'
        return 1
    fi
    
    # Parse updates
    local name=$(echo "$data" | jq -r '.name // empty')
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    
    # Update config
    local update_json=""
    [ -n "$name" ] && update_json="$update_json, \"name\": \"$name\""
    [ -n "$enabled" ] && update_json="$update_json, \"enabled\": $enabled"
    update_json="{${update_json#, }}"
    
    local updated=$(cat "$FORWARD_CONF" | jq "map(if .id == \"$id\" then . + $update_json else . end)")
    echo "$updated" > "$FORWARD_CONF"
    
    # Reapply rules
    apply_all_forwards
    
    echo '{"success": true, "message": "规则已更新"}'
}

# Delete forward rule
delete_forward() {
    local id="$1"
    init_config
    
    # Remove from config
    local updated=$(cat "$FORWARD_CONF" | jq "map(select(.id != \"$id\"))")
    echo "$updated" > "$FORWARD_CONF"
    
    # Remove from nftables
    $NFT delete rule inet clawui forward 2>/dev/null || true
    
    # Reapply remaining rules
    apply_all_forwards
    
    echo '{"success": true, "message": "规则已删除"}'
}

# Apply a single forward rule
apply_forward() {
    local id="$1"
    init_config
    
    local rule=$(cat "$FORWARD_CONF" | jq -r ".[] | select(.id == \"$id\")")
    [ -z "$rule" ] && return 1
    
    local proto=$(echo "$rule" | jq -r '.proto')
    local wan_port=$(echo "$rule" | jq -r '.wan_port')
    local lan_ip=$(echo "$rule" | jq -r '.lan_ip')
    local lan_port=$(echo "$rule" | jq -r '.lan_port')
    
    local wan_iface=$(get_wan_iface)
    
    # Add nftables rule
    $NFT add rule inet clawui forward iifname "$wan_iface" $proto dport $wan_port dnat to $lan_ip:$lan_port 2>/dev/null
}

# Apply all forward rules
apply_all_forwards() {
    init_config
    
    # Clear existing rules
    $NFT flush chain inet clawui forward 2>/dev/null || true
    
    # Create chain if not exists
    $NFT add table inet clawui 2>/dev/null || true
    $NFT add chain inet clawui forward 2>/dev/null || true
    
    # Add each enabled rule
    cat "$FORWARD_CONF" | jq -r '.[] | select(.enabled == true) | @base64' | while read rule_b64; do
        local rule=$(echo "$rule_b64" | base64 -d)
        local id=$(echo "$rule" | jq -r '.id')
        apply_forward "$id"
    done
}

# Get DMZ status
get_dmz() {
    init_config
    cat "$DMZ_CONF"
}

# Set DMZ
set_dmz() {
    read -n $CONTENT_LENGTH data
    
    local enabled=$(echo "$data" | jq -r '.enabled')
    local host=$(echo "$data" | jq -r '.host')
    
    # Validate
    if [ "$enabled" = "true" ] && [ -z "$host" ]; then
        echo '{"success": false, "message": "DMZ 主机地址必填"}'
        return 1
    fi
    
    # Save config
    cat > "$DMZ_CONF" << EOF
{
    "enabled": $enabled,
    "host": "$host"
}
EOF
    
    # Apply DMZ
    if [ "$enabled" = "true" ]; then
        apply_dmz "$host"
    else
        remove_dmz
    fi
    
    echo '{"success": true, "message": "DMZ 配置已保存"}'
}

# Apply DMZ rule
apply_dmz() {
    local host="$1"
    local wan_iface=$(get_wan_iface)
    
    # Remove existing DMZ
    remove_dmz
    
    # Add DMZ rule (forward all ports)
    $NFT add rule inet clawui dmz iifname "$wan_iface" dnat to $host 2>/dev/null || true
}

# Remove DMZ
remove_dmz() {
    $NFT flush chain inet clawui dmz 2>/dev/null || true
}

# Get UPnP status
get_upnp() {
    local enabled="false"
    local running="false"
    
    if command -v miniupnpd &>/dev/null; then
        if pgrep miniupnpd &>/dev/null; then
            running="true"
        fi
        if [ -f /etc/init.d/miniupnpd ] && rc-service miniupnpd status 2>/dev/null | grep -q started; then
            enabled="true"
        fi
    fi
    
    # Get UPnP leases
    local leases="[]"
    if [ -f /var/run/miniupnpd.leases ]; then
        leases=$(cat /var/run/miniupnpd.leases | jq -Rs 'split("\n") | map(select(length > 0))')
    fi
    
    cat << EOF
{
    "installed": $(command -v miniupnpd &>/dev/null && echo 'true' || echo 'false'),
    "enabled": $enabled,
    "running": $running,
    "leases": $leases
}
EOF
}

# Toggle UPnP
toggle_upnp() {
    read -n $CONTENT_LENGTH data
    local enabled=$(echo "$data" | jq -r '.enabled')
    
    if [ "$enabled" = "true" ]; then
        rc-service miniupnpd start 2>/dev/null && \
            echo '{"success": true, "message": "UPnP 已启用"}' || \
            echo '{"success": false, "message": "UPnP 启用失败，请确认已安装 miniupnpd"}'
    else
        rc-service miniupnpd stop 2>/dev/null
        echo '{"success": true, "message": "UPnP 已禁用"}'
    fi
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/portforward/forwards/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/portforward/forwards/||')
                get_forward "$id"
                ;;
            /api/apps/portforward/forwards)
                list_forwards
                ;;
            /api/apps/portforward/dmz)
                get_dmz
                ;;
            /api/apps/portforward/upnp)
                get_upnp
                ;;
            *)
                list_forwards
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/portforward/forwards)
                add_forward
                ;;
            /api/apps/portforward/forwards/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/portforward/forwards/||')
                update_forward "$id"
                ;;
            /api/apps/portforward/dmz)
                set_dmz
                ;;
            /api/apps/portforward/upnp)
                toggle_upnp
                ;;
            /api/apps/portforward/apply)
                apply_all_forwards
                echo '{"success": true, "message": "规则已应用"}'
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/portforward/forwards/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/portforward/forwards/||')
                delete_forward "$id"
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