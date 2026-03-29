#!/bin/sh
# ClawUI Multi-WAN App API
# Multi-WAN load balancing and failover

IP="/sbin/ip"
IPT="/sbin/iptables"
CONF_DIR="/etc/clawui/multiwan"
WANS_CONF="$CONF_DIR/wans.json"
RULES_CONF="$CONF_DIR/rules.json"
STATUS_FILE="/var/run/multiwan.status"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize
init_config() {
    mkdir -p "$CONF_DIR"
    [ ! -f "$WANS_CONF" ] && echo '[]' > "$WANS_CONF"
    [ ! -f "$RULES_CONF" ] && echo '{"enabled": false, "mode": "balance", "check_interval": 10}' > "$RULES_CONF"
}

# Get Multi-WAN status
get_status() {
    init_config
    
    local enabled=$(cat "$RULES_CONF" | jq -r '.enabled')
    local mode=$(cat "$RULES_CONF" | jq -r '.mode')
    local wans=$(cat "$WANS_CONF")
    local active_count=$(echo "$wans" | jq '[.[] | select(.enabled == true and .status == "online")] | length')
    local total_count=$(echo "$wans" | jq 'length')
    
    # Get current routing table summary
    local default_routes=$($IP route show table main | grep default | jq -Rs 'split("\n") | map(select(length > 0))')
    
    cat << EOF
{
    "enabled": $enabled,
    "mode": "$mode",
    "active_wans": $active_count,
    "total_wans": $total_count,
    "wans": $wans,
    "default_routes": $default_routes
}
EOF
}

# List WAN interfaces
list_wans() {
    init_config
    cat "$WANS_CONF"
}

# Detect available WAN interfaces
detect_wans() {
    local result="["
    local first=1
    
    # Check for physical interfaces
    for iface in eth0 eth1 eth2 eth3 usb0 usb1; do
        if ip link show $iface &>/dev/null; then
            local ip_addr=$(ip addr show $iface 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
            local mac=$(ip link show $iface 2>/dev/null | grep ether | awk '{print $2}')
            local carrier=$(cat /sys/class/net/$iface/carrier 2>/dev/null || echo 0)
            local operstate=$(cat /sys/class/net/$iface/operstate 2>/dev/null || echo "unknown")
            
            [ "$first" = "0" ] && result="$result,"
            first=0
            
            result="$result{\"interface\": \"$iface\", \"mac\": \"$mac\", \"ip\": \"${ip_addr:-}\", \"carrier\": $carrier, \"operstate\": \"$operstate\", \"detected\": true}"
        fi
    done
    
    # Check for PPP interfaces
    for iface in ppp0 ppp1 ppp2; do
        if ip link show $iface &>/dev/null; then
            local ip_addr=$(ip addr show $iface 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
            local peer=$(ip addr show $iface 2>/dev/null | grep 'peer' | awk '{print $2}' | cut -d/ -f1)
            
            [ "$first" = "0" ] && result="$result,"
            first=0
            
            result="$result{\"interface\": \"$iface\", \"ip\": \"${ip_addr:-}\", \"peer\": \"${peer:-}\", \"type\": \"ppp\", \"carrier\": 1, \"detected\": true}"
        fi
    done
    
    result="$result]"
    echo "$result"
}

# Add WAN interface
add_wan() {
    read -n $CONTENT_LENGTH data
    
    local interface=$(echo "$data" | jq -r '.interface')
    local name=$(echo "$data" | jq -r '.name // .interface')
    local weight=$(echo "$data" | jq -r '.weight // 1')
    local check_host=$(echo "$data" | jq -r '.check_host // "8.8.8.8"')
    local check_type=$(echo "$data" | jq -r '.check_type // "ping"')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    local failover=$(echo "$data" | jq -r '.failover // false')
    
    # Validate
    if [ -z "$interface" ]; then
        echo '{"success": false, "message": "接口名称必填"}'
        return 1
    fi
    
    # Check if interface exists
    if ! ip link show "$interface" &>/dev/null; then
        echo '{"success": false, "message": "接口不存在"}'
        return 1
    fi
    
    # Check for duplicates
    if cat "$WANS_CONF" | jq -e ".[] | select(.interface == \"$interface\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "该接口已配置"}'
        return 1
    fi
    
    # Get current IP
    local ip_addr=$(ip addr show $interface 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    local gateway=$(ip route show dev $interface | grep default | awk '{print $3}')
    
    # Create WAN entry
    local new_wan=$(cat << EOF
{
    "id": "wan-$interface",
    "interface": "$interface",
    "name": "$name",
    "weight": $weight,
    "check_host": "$check_host",
    "check_type": "$check_type",
    "enabled": $enabled,
    "failover": $failover,
    "ip": "${ip_addr:-}",
    "gateway": "${gateway:-}",
    "status": "unknown",
    "last_check": ""
}
EOF
)
    
    # Save
    local updated=$(cat "$WANS_CONF" | jq ". + [$new_wan]")
    echo "$updated" > "$WANS_CONF"
    
    echo "{\"success\": true, \"message\": \"WAN 接口已添加\", \"id\": \"wan-$interface\"}"
}

# Update WAN config
update_wan() {
    local id="$1"
    read -n $CONTENT_LENGTH data
    
    init_config
    
    # Parse updates
    local weight=$(echo "$data" | jq -r '.weight // empty')
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local check_host=$(echo "$data" | jq -r '.check_host // empty')
    local name=$(echo "$data" | jq -r '.name // empty')
    
    # Build update
    local updates="{}"
    [ -n "$weight" ] && updates=$(echo "$updates" | jq ". + {\"weight\": $weight}")
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$check_host" ] && updates=$(echo "$updates" | jq ". + {\"check_host\": \"$check_host\"}")
    [ -n "$name" ] && updates=$(echo "$updates" | jq ". + {\"name\": \"$name\"}")
    
    # Apply
    local updated=$(cat "$WANS_CONF" | jq "map(if .id == \"$id\" then . + $updates else . end)")
    echo "$updated" > "$WANS_CONF"
    
    # Reapply rules if enabled
    if [ "$enabled" = "true" ]; then
        apply_multiwan
    fi
    
    echo '{"success": true, "message": "配置已更新"}'
}

# Delete WAN
delete_wan() {
    local id="$1"
    init_config
    
    local updated=$(cat "$WANS_CONF" | jq "map(select(.id != \"$id\"))")
    echo "$updated" > "$WANS_CONF"
    
    # Reapply
    apply_multiwan
    
    echo '{"success": true, "message": "WAN 已删除"}'
}

# Check WAN health
check_wan_health() {
    local id="$1"
    init_config
    
    local wan=$(cat "$WANS_CONF" | jq -r ".[] | select(.id == \"$id\")")
    if [ -z "$wan" ]; then
        echo '{"error": "WAN not found"}'
        return 1
    fi
    
    local interface=$(echo "$wan" | jq -r '.interface')
    local check_host=$(echo "$wan" | jq -r '.check_host')
    local check_type=$(echo "$wan" | jq -r '.check_type')
    local gateway=$(echo "$wan" | jq -r '.gateway')
    
    local status="offline"
    local latency=0
    
    # Check carrier first
    local carrier=$(cat /sys/class/net/$interface/carrier 2>/dev/null || echo 0)
    
    if [ "$carrier" = "1" ]; then
        case "$check_type" in
            ping)
                if ping -I "$interface" -c 3 -W 2 "$check_host" &>/dev/null; then
                    status="online"
                    latency=$(ping -I "$interface" -c 3 "$check_host" 2>/dev/null | tail -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
                fi
                ;;
            http)
                if curl -s --interface "$interface" --max-time 5 "http://$check_host" &>/dev/null; then
                    status="online"
                fi
                ;;
        esac
    fi
    
    # Update status
    local updated=$(cat "$WANS_CONF" | jq "map(if .id == \"$id\" then . + {\"status\": \"$status\", \"latency\": ${latency:-0}, \"last_check\": \"$(date -Iseconds)\"} else . end)")
    echo "$updated" > "$WANS_CONF"
    
    cat << EOF
{
    "id": "$id",
    "interface": "$interface",
    "status": "$status",
    "latency": ${latency:-0},
    "carrier": $carrier,
    "last_check": "$(date -Iseconds)"
}
EOF
}

# Check all WANs health
check_all_health() {
    init_config
    
    local ids=$(cat "$WANS_CONF" | jq -r '.[].id')
    for id in $ids; do
        check_wan_health "$id" >/dev/null 2>&1 &
    done
    
    # Wait a bit
    sleep 3
    
    # Return updated status
    cat "$WANS_CONF"
}

# Apply Multi-WAN configuration
apply_multiwan() {
    init_config
    
    local mode=$(cat "$RULES_CONF" | jq -r '.mode')
    local enabled=$(cat "$RULES_CONF" | jq -r '.enabled')
    
    if [ "$enabled" != "true" ]; then
        # Disable - restore default routing
        restore_default_routing
        echo '{"success": true, "message": "多线负载已禁用"}'
        return
    fi
    
    # Clear existing rules
    $IP route flush table 100 2>/dev/null
    $IP route flush table 101 2>/dev/null
    $IP route flush table 102 2>/dev/null
    
    # Get enabled online WANs
    local online_wans=$(cat "$WANS_CONF" | jq -r '.[] | select(.enabled == true and .status == "online")')
    
    if [ -z "$online_wans" ]; then
        echo '{"success": false, "message": "没有可用的在线 WAN 接口"}'
        return 1
    fi
    
    case "$mode" in
        balance)
            apply_load_balance "$online_wans"
            ;;
        failover)
            apply_failover "$online_wans"
            ;;
        weighted)
            apply_weighted "$online_wans"
            ;;
    esac
    
    echo '{"success": true, "message": "配置已应用"}'
}

# Apply load balancing
apply_load_balance() {
    local wans="$1"
    local table_id=100
    
    echo "$wans" | jq -c '.' | while read wan; do
        local interface=$(echo "$wan" | jq -r '.interface')
        local gateway=$(echo "$wan" | jq -r '.gateway')
        
        if [ -n "$gateway" ]; then
            # Add routing table
            $IP route add default via $gateway dev $interface table $table_id
            
            # Add rule
            $IP rule add from $(ip addr show $interface | grep 'inet ' | awk '{print $2}') table $table_id
            
            table_id=$((table_id + 1))
        fi
    done
    
    # Add default routes with equal cost
    local count=$(echo "$wans" | jq -s 'length')
    echo "$wans" | jq -c '.' | while read wan; do
        local interface=$(echo "$wan" | jq -r '.interface')
        local gateway=$(echo "$wan" | jq -r '.gateway')
        
        if [ -n "$gateway" ]; then
            $IP route add default via $gateway dev $interface metric $((count * 100))
            count=$((count - 1))
        fi
    done
}

# Apply failover mode
apply_failover() {
    local wans="$1"
    
    # Get WAN with highest weight (primary)
    local primary=$(echo "$wans" | jq -s 'sort_by(.weight) | reverse | .[0]')
    local primary_iface=$(echo "$primary" | jq -r '.interface')
    local primary_gw=$(echo "$primary" | jq -r '.gateway')
    
    # Set primary as default
    if [ -n "$primary_gw" ]; then
        $IP route replace default via $primary_gw dev $primary_iface metric 100
    fi
    
    # Add backup routes with higher metric
    local metric=200
    echo "$wans" | jq -c '.' | while read wan; do
        local interface=$(echo "$wan" | jq -r '.interface')
        local gateway=$(echo "$wan" | jq -r '.gateway')
        
        if [ "$interface" != "$primary_iface" ] && [ -n "$gateway" ]; then
            $IP route add default via $gateway dev $interface metric $metric
            metric=$((metric + 100))
        fi
    done
}

# Apply weighted load balancing
apply_weighted() {
    local wans="$1"
    
    # Calculate total weight
    local total_weight=$(echo "$wans" | jq -s '[.[].weight] | add')
    
    # Create routing tables based on weight
    local table_id=100
    echo "$wans" | jq -c '.' | while read wan; do
        local interface=$(echo "$wan" | jq -r '.interface')
        local gateway=$(echo "$wan" | jq -r '.gateway')
        local weight=$(echo "$wan" | jq -r '.weight')
        
        if [ -n "$gateway" ]; then
            # Add route with weight-based probability
            for i in $(seq 1 $weight); do
                $IP route add default via $gateway dev $interface metric $((1000 - table_id * weight + i)) 2>/dev/null
            done
        fi
        
        table_id=$((table_id + 1))
    done
}

# Restore default routing
restore_default_routing() {
    # Flush custom rules
    $IP rule del table 100 2>/dev/null || true
    $IP rule del table 101 2>/dev/null || true
    $IP rule del table 102 2>/dev/null || true
    
    # Keep main table default
    echo "Restored default routing"
}

# Update settings
update_settings() {
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local mode=$(echo "$data" | jq -r '.mode // empty')
    local check_interval=$(echo "$data" | jq -r '.check_interval // empty')
    
    local updates="{}"
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$mode" ] && updates=$(echo "$updates" | jq ". + {\"mode\": \"$mode\"}")
    [ -n "$check_interval" ] && updates=$(echo "$updates" | jq ". + {\"check_interval\": $check_interval}")
    
    local updated=$(cat "$RULES_CONF" | jq ". + $updates")
    echo "$updated" > "$RULES_CONF"
    
    # Apply if enabled
    if [ "$enabled" = "true" ]; then
        check_all_health >/dev/null 2>&1
        apply_multiwan
    else
        restore_default_routing
    fi
    
    echo '{"success": true, "message": "设置已保存"}'
}

# Get settings
get_settings() {
    init_config
    cat "$RULES_CONF"
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/multiwan/wans/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/multiwan/wans/||')
                cat "$WANS_CONF" | jq ".[] | select(.id == \"$id\")"
                ;;
            /api/apps/multiwan/wans)
                list_wans
                ;;
            /api/apps/multiwan/detect)
                detect_wans
                ;;
            /api/apps/multiwan/health/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/multiwan/health/||')
                check_wan_health "$id"
                ;;
            /api/apps/multiwan/health)
                check_all_health
                ;;
            /api/apps/multiwan/settings)
                get_settings
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/multiwan/wans)
                add_wan
                ;;
            /api/apps/multiwan/wans/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/multiwan/wans/||')
                update_wan "$id"
                ;;
            /api/apps/multiwan/settings)
                update_settings
                ;;
            /api/apps/multiwan/apply)
                apply_multiwan
                ;;
            /api/apps/multiwan/health)
                check_all_health >/dev/null 2>&1
                get_status
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/multiwan/wans/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/multiwan/wans/||')
                delete_wan "$id"
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