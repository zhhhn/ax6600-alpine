#!/bin/sh
# ClawUI QoS App API
# Traffic shaping and QoS control

TC="/sbin/tc"
IP="/sbin/ip"
CONF_DIR="/etc/clawui/qos"
RULES_CONF="$CONF_DIR/rules.json"
SETTINGS_CONF="$CONF_DIR/settings.json"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize
init_config() {
    mkdir -p "$CONF_DIR"
    [ ! -f "$RULES_CONF" ] && echo '[]' > "$RULES_CONF"
    [ ! -f "$SETTINGS_CONF" ] && echo '{"enabled": false, "wan_interface": "eth0", "download_speed": 100000, "upload_speed": 50000}' > "$SETTINGS_CONF"
}

# Get QoS status
get_status() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local rules=$(cat "$RULES_CONF")
    local enabled=$(echo "$settings" | jq -r '.enabled')
    
    # Check if tc is running
    local tc_active="false"
    if $TC qdisc show | grep -q "htb\|fq_codel"; then
        tc_active="true"
    fi
    
    # Get current qdisc stats
    local qdiscs=$($TC qdisc show 2>/dev/null | jq -Rs 'split("\n") | map(select(length > 0))')
    local classes=$($TC class show 2>/dev/null | jq -Rs 'split("\n") | map(select(length > 0))')
    
    cat << EOF
{
    "enabled": $enabled,
    "tc_active": $tc_active,
    "settings": $settings,
    "rules": $rules,
    "qdiscs": $qdiscs,
    "classes": $classes
}
EOF
}

# Get settings
get_settings() {
    init_config
    cat "$SETTINGS_CONF"
}

# Update settings
update_settings() {
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local wan_interface=$(echo "$data" | jq -r '.wan_interface // empty')
    local download_speed=$(echo "$data" | jq -r '.download_speed // empty')
    local upload_speed=$(echo "$data" | jq -r '.upload_speed // empty')
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local default_prio=$(echo "$data" | jq -r '.default_prio // empty')
    
    local updates="{}"
    [ -n "$wan_interface" ] && updates=$(echo "$updates" | jq ". + {\"wan_interface\": \"$wan_interface\"}")
    [ -n "$download_speed" ] && updates=$(echo "$updates" | jq ". + {\"download_speed\": $download_speed}")
    [ -n "$upload_speed" ] && updates=$(echo "$updates" | jq ". + {\"upload_speed\": $upload_speed}")
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$default_prio" ] && updates=$(echo "$updates" | jq ". + {\"default_prio\": \"$default_prio\"}")
    
    local updated=$(cat "$SETTINGS_CONF" | jq ". + $updates")
    echo "$updated" > "$SETTINGS_CONF"
    
    # Apply if enabled
    if [ "$enabled" = "true" ]; then
        apply_qos
    else
        clear_qos
    fi
    
    echo '{"success": true, "message": "设置已保存"}'
}

# List QoS rules
list_rules() {
    init_config
    cat "$RULES_CONF"
}

# Add QoS rule
add_rule() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local proto=$(echo "$data" | jq -r '.proto // "all"')
    local src_ip=$(echo "$data" | jq -r '.src_ip // ""')
    local dst_ip=$(echo "$data" | jq -r '.dst_ip // ""')
    local src_port=$(echo "$data" | jq -r '.src_port // ""')
    local dst_port=$(echo "$data" | jq -r '.dst_port // ""')
    local priority=$(echo "$data" | jq -r '.priority // "normal"')
    local rate_limit=$(echo "$data" | jq -r '.rate_limit // 0')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    local comment=$(echo "$data" | jq -r '.comment // ""')
    
    # Validate
    if [ -z "$name" ]; then
        echo '{"success": false, "message": "规则名称必填"}'
        return 1
    fi
    
    # Generate ID
    local id=$(echo "$priority-$proto-$src_ip-$dst_ip-$src_port-$dst_port" | tr './' '--' | tr -s '-')
    
    # Check for duplicates
    if cat "$RULES_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "规则已存在"}'
        return 1
    fi
    
    # Map priority to class
    local prio_num=3
    case "$priority" in
        high) prio_num=1 ;;
        medium) prio_num=2 ;;
        normal) prio_num=3 ;;
        low) prio_num=4 ;;
        bulk) prio_num=5 ;;
    esac
    
    # Create rule
    local new_rule=$(cat << EOF
{
    "id": "$id",
    "name": "$name",
    "proto": "$proto",
    "src_ip": "$src_ip",
    "dst_ip": "$dst_ip",
    "src_port": "$src_port",
    "dst_port": "$dst_port",
    "priority": "$priority",
    "prio_num": $prio_num,
    "rate_limit": $rate_limit,
    "enabled": $enabled,
    "comment": "$comment",
    "created_at": "$(date -Iseconds)"
}
EOF
)
    
    local updated=$(cat "$RULES_CONF" | jq ". + [$new_rule]")
    echo "$updated" > "$RULES_CONF"
    
    # Reapply if enabled
    local qos_enabled=$(cat "$SETTINGS_CONF" | jq -r '.enabled')
    if [ "$qos_enabled" = "true" ]; then
        apply_qos
    fi
    
    echo "{\"success\": true, \"message\": \"规则已添加\", \"id\": \"$id\"}"
}

# Update rule
update_rule() {
    local id="$1"
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local priority=$(echo "$data" | jq -r '.priority // empty')
    local rate_limit=$(echo "$data" | jq -r '.rate_limit // empty')
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local name=$(echo "$data" | jq -r '.name // empty')
    
    local updates="{}"
    [ -n "$name" ] && updates=$(echo "$updates" | jq ". + {\"name\": \"$name\"}")
    [ -n "$rate_limit" ] && updates=$(echo "$updates" | jq ". + {\"rate_limit\": $rate_limit}")
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    
    if [ -n "$priority" ]; then
        local prio_num=3
        case "$priority" in
            high) prio_num=1 ;;
            medium) prio_num=2 ;;
            normal) prio_num=3 ;;
            low) prio_num=4 ;;
            bulk) prio_num=5 ;;
        esac
        updates=$(echo "$updates" | jq ". + {\"priority\": \"$priority\", \"prio_num\": $prio_num}")
    fi
    
    local updated=$(cat "$RULES_CONF" | jq "map(if .id == \"$id\" then . + $updates else . end)")
    echo "$updated" > "$RULES_CONF"
    
    # Reapply
    local qos_enabled=$(cat "$SETTINGS_CONF" | jq -r '.enabled')
    if [ "$qos_enabled" = "true" ]; then
        apply_qos
    fi
    
    echo '{"success": true, "message": "规则已更新"}'
}

# Delete rule
delete_rule() {
    local id="$1"
    init_config
    
    local updated=$(cat "$RULES_CONF" | jq "map(select(.id != \"$id\"))")
    echo "$updated" > "$RULES_CONF"
    
    # Reapply
    apply_qos
    
    echo '{"success": true, "message": "规则已删除"}'
}

# Apply QoS configuration
apply_qos() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local wan_interface=$(echo "$settings" | jq -r '.wan_interface')
    local download_speed=$(echo "$settings" | jq -r '.download_speed')
    local upload_speed=$(echo "$settings" | jq -r '.upload_speed')
    
    if [ -z "$wan_interface" ]; then
        echo '{"success": false, "message": "WAN 接口未配置"}'
        return 1
    fi
    
    # Clear existing rules
    $TC qdisc del dev $wan_interface root 2>/dev/null
    $TC qdisc del dev $wan_interface ingress 2>/dev/null
    
    # Create root qdisc (HTB)
    $TC qdisc add dev $wan_interface root handle 1: htb default 30
    $TC class add dev $wan_interface parent 1: classid 1:1 htb rate ${upload_speed}kbit ceil ${upload_speed}kbit
    
    # Create priority classes
    # High priority (VOIP, gaming)
    $TC class add dev $wan_interface parent 1:1 classid 1:10 htb rate $((upload_speed * 30 / 100))kbit ceil ${upload_speed}kbit prio 1
    $TC qdisc add dev $wan_interface parent 1:10 handle 10: fq_codel
    
    # Medium priority (interactive)
    $TC class add dev $wan_interface parent 1:1 classid 1:20 htb rate $((upload_speed * 25 / 100))kbit ceil ${upload_speed}kbit prio 2
    $TC qdisc add dev $wan_interface parent 1:20 handle 20: fq_codel
    
    # Normal priority (default)
    $TC class add dev $wan_interface parent 1:1 classid 1:30 htb rate $((upload_speed * 25 / 100))kbit ceil ${upload_speed}kbit prio 3
    $TC qdisc add dev $wan_interface parent 1:30 handle 30: fq_codel
    
    # Low priority (background)
    $TC class add dev $wan_interface parent 1:1 classid 1:40 htb rate $((upload_speed * 15 / 100))kbit ceil ${upload_speed}kbit prio 4
    $TC qdisc add dev $wan_interface parent 1:40 handle 40: fq_codel
    
    # Bulk (downloads)
    $TC class add dev $wan_interface parent 1:1 classid 1:50 htb rate $((upload_speed * 5 / 100))kbit ceil ${upload_speed}kbit prio 5
    $TC qdisc add dev $wan_interface parent 1:50 handle 50: fq_codel
    
    # Apply custom rules
    local rules=$(cat "$RULES_CONF" | jq -r '.[] | select(.enabled == true)')
    if [ -n "$rules" ]; then
        echo "$rules" | jq -c '.' | while read rule; do
            local proto=$(echo "$rule" | jq -r '.proto')
            local src_ip=$(echo "$rule" | jq -r '.src_ip')
            local dst_ip=$(echo "$rule" | jq -r '.dst_ip')
            local src_port=$(echo "$rule" | jq -r '.src_port')
            local dst_port=$(echo "$rule" | jq -r '.dst_port')
            local prio_num=$(echo "$rule" | jq -r '.prio_num')
            
            # Build filter
            local filter="protocol ip"
            [ "$proto" != "all" ] && filter="protocol $proto"
            
            local match=""
            [ -n "$src_ip" ] && match="$match src $src_ip"
            [ -n "$dst_ip" ] && match="$match dst $dst_ip"
            [ -n "$src_port" ] && match="$match sport $src_port"
            [ -n "$dst_port" ] && match="$match dport $dst_port"
            
            local classid=$((10 + (prio_num - 1) * 10))
            
            # Add filter
            $TC filter add dev $wan_interface parent 1:0 $filter prio 1 u32 match $match flowid 1:$classid 2>/dev/null
        done
    fi
    
    # Setup ingress qdisc for download (IFB)
    if modprobe ifb 2>/dev/null; then
        $IP link add ifb0 type ifb 2>/dev/null
        $IP link set ifb0 up
        
        $TC qdisc add dev $wan_interface ingress
        $TC filter add dev $wan_interface parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
        
        $TC qdisc add dev ifb0 root handle 1: htb default 30
        $TC class add dev ifb0 parent 1: classid 1:1 htb rate ${download_speed}kbit ceil ${download_speed}kbit
        
        # Similar classes for download
        $TC class add dev ifb0 parent 1:1 classid 1:10 htb rate $((download_speed * 30 / 100))kbit ceil ${download_speed}kbit prio 1
        $TC class add dev ifb0 parent 1:1 classid 1:20 htb rate $((download_speed * 25 / 100))kbit ceil ${download_speed}kbit prio 2
        $TC class add dev ifb0 parent 1:1 classid 1:30 htb rate $((download_speed * 25 / 100))kbit ceil ${download_speed}kbit prio 3
        $TC class add dev ifb0 parent 1:1 classid 1:40 htb rate $((download_speed * 15 / 100))kbit ceil ${download_speed}kbit prio 4
        $TC class add dev ifb0 parent 1:1 classid 1:50 htb rate $((download_speed * 5 / 100))kbit ceil ${download_speed}kbit prio 5
    fi
    
    echo '{"success": true, "message": "QoS 配置已应用"}'
}

# Clear QoS rules
clear_qos() {
    init_config
    
    local wan_interface=$(cat "$SETTINGS_CONF" | jq -r '.wan_interface')
    
    $TC qdisc del dev $wan_interface root 2>/dev/null
    $TC qdisc del dev $wan_interface ingress 2>/dev/null
    $TC qdisc del dev ifb0 root 2>/dev/null
    $IP link del ifb0 2>/dev/null
    
    echo '{"success": true, "message": "QoS 已清除"}'
}

# Get traffic statistics
get_stats() {
    init_config
    
    local wan_interface=$(cat "$SETTINGS_CONF" | jq -r '.wan_interface')
    
    # Get class stats
    local stats=$($TC -s class show dev $wan_interface 2>/dev/null | jq -Rs '.')
    
    echo "{\"interface\": \"$wan_interface\", \"stats\": $stats}"
}

# Preset rules
get_presets() {
    cat << EOF
{
    "presets": [
        {
            "id": "gaming",
            "name": "游戏优先",
            "rules": [
                {"proto": "udp", "dst_port": "3074", "priority": "high", "comment": "Xbox Live"},
                {"proto": "udp", "dst_port": "3478-3479", "priority": "high", "comment": "Stun"},
                {"proto": "tcp", "dst_port": "27015-27030", "priority": "high", "comment": "Steam"}
            ]
        },
        {
            "id": "voip",
            "name": "VoIP优先",
            "rules": [
                {"proto": "udp", "dst_port": "5060", "priority": "high", "comment": "SIP"},
                {"proto": "udp", "dst_port": "10000-20000", "priority": "high", "comment": "RTP"},
                {"proto": "udp", "dst_port": "3478", "priority": "high", "comment": "STUN"}
            ]
        },
        {
            "id": "streaming",
            "name": "流媒体优先",
            "rules": [
                {"proto": "tcp", "dst_port": "443", "priority": "medium", "comment": "HTTPS"},
                {"proto": "tcp", "dst_port": "1935", "priority": "medium", "comment": "RTMP"}
            ]
        },
        {
            "id": "work",
            "name": "办公优先",
            "rules": [
                {"proto": "tcp", "dst_port": "22", "priority": "high", "comment": "SSH"},
                {"proto": "tcp", "dst_port": "3389", "priority": "high", "comment": "RDP"},
                {"proto": "tcp", "dst_port": "5900", "priority": "high", "comment": "VNC"}
            ]
        }
    ]
}
EOF
}

# Apply preset
apply_preset() {
    local preset_id="$1"
    
    local presets=$(get_presets)
    local preset=$(echo "$presets" | jq -r ".presets[] | select(.id == \"$preset_id\")")
    
    if [ -z "$preset" ]; then
        echo '{"success": false, "message": "预设不存在"}'
        return 1
    fi
    
    # Add rules from preset
    echo "$preset" | jq -r '.rules[] | @base64' | while read rule_b64; do
        local rule=$(echo "$rule_b64" | base64 -d)
        local proto=$(echo "$rule" | jq -r '.proto')
        local dst_port=$(echo "$rule" | jq -r '.dst_port')
        local priority=$(echo "$rule" | jq -r '.priority')
        local comment=$(echo "$rule" | jq -r '.comment')
        
        # Create rule via API (simplified)
        add_rule_preset "$proto" "$dst_port" "$priority" "$comment"
    done
    
    echo "{\"success\": true, \"message\": \"预设 $preset_id 已应用\"}"
}

add_rule_preset() {
    local proto="$1"
    local dst_port="$2"
    local priority="$3"
    local comment="$4"
    
    local name="$comment"
    local id=$(echo "$priority-$proto-$dst_port" | tr './' '--')
    
    local prio_num=3
    case "$priority" in
        high) prio_num=1 ;;
        medium) prio_num=2 ;;
        normal) prio_num=3 ;;
        low) prio_num=4 ;;
    esac
    
    local new_rule=$(cat << EOF
{
    "id": "$id",
    "name": "$name",
    "proto": "$proto",
    "dst_port": "$dst_port",
    "priority": "$priority",
    "prio_num": $prio_num,
    "enabled": true,
    "comment": "$comment"
}
EOF
)
    
    # Check if exists
    if ! cat "$RULES_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        local updated=$(cat "$RULES_CONF" | jq ". + [$new_rule]")
        echo "$updated" > "$RULES_CONF"
    fi
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/qos/rules/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/qos/rules/||')
                cat "$RULES_CONF" | jq ".[] | select(.id == \"$id\")"
                ;;
            /api/apps/qos/rules)
                list_rules
                ;;
            /api/apps/qos/settings)
                get_settings
                ;;
            /api/apps/qos/stats)
                get_stats
                ;;
            /api/apps/qos/presets)
                get_presets
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/qos/rules)
                add_rule
                ;;
            /api/apps/qos/rules/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/qos/rules/||')
                update_rule "$id"
                ;;
            /api/apps/qos/settings)
                update_settings
                ;;
            /api/apps/qos/apply)
                apply_qos
                ;;
            /api/apps/qos/clear)
                clear_qos
                ;;
            /api/apps/qos/presets/*)
                local preset_id=$(echo "$PATH_INFO" | sed 's|/api/apps/qos/presets/||')
                apply_preset "$preset_id"
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/qos/rules/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/qos/rules/||')
                delete_rule "$id"
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