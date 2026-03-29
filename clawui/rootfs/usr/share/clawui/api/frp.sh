#!/bin/sh
# ClawUI FRP Client App API
# FRP intranet penetration client management

CONF_DIR="/etc/clawui/frp"
CLIENT_CONF="$CONF_DIR/frpc.toml"
PROXIES_CONF="$CONF_DIR/proxies.json"
SETTINGS_CONF="$CONF_DIR/settings.json"
FRPC="/usr/bin/frpc"
PID_FILE="/var/run/frpc.pid"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize
init_config() {
    mkdir -p "$CONF_DIR"
    [ ! -f "$PROXIES_CONF" ] && echo '[]' > "$PROXIES_CONF"
    [ ! -f "$SETTINGS_CONF" ] && echo '{"enabled": false, "server_addr": "", "server_port": 7000, "token": ""}' > "$SETTINGS_CONF"
}

# Get FRP status
get_status() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local proxies=$(cat "$PROXIES_CONF")
    local enabled=$(echo "$settings" | jq -r '.enabled')
    local running="false"
    local pid=""
    
    # Check if frpc is running
    if pgrep -f "frpc" &>/dev/null; then
        running="true"
        pid=$(pgrep -f "frpc" | head -1)
    fi
    
    # Check if installed
    local installed="false"
    if [ -x "$FRPC" ]; then
        installed="true"
    fi
    
    cat << EOF
{
    "installed": $installed,
    "enabled": $enabled,
    "running": $running,
    "pid": "${pid:-}",
    "settings": $settings,
    "proxies": $proxies
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
    
    local server_addr=$(echo "$data" | jq -r '.server_addr // empty')
    local server_port=$(echo "$data" | jq -r '.server_port // empty')
    local token=$(echo "$data" | jq -r '.token // empty')
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local log_level=$(echo "$data" | jq -r '.log_level // empty')
    local protocol=$(echo "$data" | jq -r '.protocol // empty')
    
    local updates="{}"
    [ -n "$server_addr" ] && updates=$(echo "$updates" | jq ". + {\"server_addr\": \"$server_addr\"}")
    [ -n "$server_port" ] && updates=$(echo "$updates" | jq ". + {\"server_port\": $server_port}")
    [ -n "$token" ] && updates=$(echo "$updates" | jq ". + {\"token\": \"$token\"}")
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$log_level" ] && updates=$(echo "$updates" | jq ". + {\"log_level\": \"$log_level\"}")
    [ -n "$protocol" ] && updates=$(echo "$updates" | jq ". + {\"protocol\": \"$protocol\"}")
    
    local updated=$(cat "$SETTINGS_CONF" | jq ". + $updates")
    echo "$updated" > "$SETTINGS_CONF"
    
    # Regenerate config file
    generate_config
    
    # Restart if running
    if [ "$enabled" = "true" ]; then
        restart_frp
    fi
    
    echo '{"success": true, "message": "设置已保存"}'
}

# List proxies
list_proxies() {
    init_config
    cat "$PROXIES_CONF"
}

# Add proxy
add_proxy() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local type=$(echo "$data" | jq -r '.type // "tcp"')
    local local_ip=$(echo "$data" | jq -r '.local_ip // "127.0.0.1"')
    local local_port=$(echo "$data" | jq -r '.local_port')
    local remote_port=$(echo "$data" | jq -r '.remote_port // 0')
    local custom_domain=$(echo "$data" | jq -r '.custom_domain // ""')
    local subdomain=$(echo "$data" | jq -r '.subdomain // ""')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    
    # Validate
    if [ -z "$name" ] || [ -z "$local_port" ]; then
        echo '{"success": false, "message": "名称和本地端口必填"}'
        return 1
    fi
    
    # Check for duplicates
    if cat "$PROXIES_CONF" | jq -e ".[] | select(.name == \"$name\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "代理名称已存在"}'
        return 1
    fi
    
    # Create proxy entry
    local new_proxy=$(cat << EOF
{
    "name": "$name",
    "type": "$type",
    "local_ip": "$local_ip",
    "local_port": $local_port,
    "remote_port": $remote_port,
    "custom_domain": "$custom_domain",
    "subdomain": "$subdomain",
    "enabled": $enabled,
    "created_at": "$(date -Iseconds)"
}
EOF
)
    
    local updated=$(cat "$PROXIES_CONF" | jq ". + [$new_proxy]")
    echo "$updated" > "$PROXIES_CONF"
    
    # Regenerate config
    generate_config
    
    # Restart if running
    if pgrep -f "frpc" &>/dev/null; then
        restart_frp
    fi
    
    echo "{\"success\": true, \"message\": \"代理已添加\", \"name\": \"$name\"}"
}

# Update proxy
update_proxy() {
    local name="$1"
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local local_port=$(echo "$data" | jq -r '.local_port // empty')
    local remote_port=$(echo "$data" | jq -r '.remote_port // empty')
    
    local updates="{}"
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$local_port" ] && updates=$(echo "$updates" | jq ". + {\"local_port\": $local_port}")
    [ -n "$remote_port" ] && updates=$(echo "$updates" | jq ". + {\"remote_port\": $remote_port}")
    
    local updated=$(cat "$PROXIES_CONF" | jq "map(if .name == \"$name\" then . + $updates else . end)")
    echo "$updated" > "$PROXIES_CONF"
    
    generate_config
    
    if pgrep -f "frpc" &>/dev/null; then
        restart_frp
    fi
    
    echo '{"success": true, "message": "代理已更新"}'
}

# Delete proxy
delete_proxy() {
    local name="$1"
    init_config
    
    local updated=$(cat "$PROXIES_CONF" | jq "map(select(.name != \"$name\"))")
    echo "$updated" > "$PROXIES_CONF"
    
    generate_config
    
    if pgrep -f "frpc" &>/dev/null; then
        restart_frp
    fi
    
    echo '{"success": true, "message": "代理已删除"}'
}

# Generate FRP config file
generate_config() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local server_addr=$(echo "$settings" | jq -r '.server_addr')
    local server_port=$(echo "$settings" | jq -r '.server_port')
    local token=$(echo "$settings" | jq -r '.token')
    local log_level=$(echo "$settings" | jq -r '.log_level // "info"')
    local protocol=$(echo "$settings" | jq -r '.protocol // "tcp"')
    
    # Generate TOML config
    cat > "$CLIENT_CONF" << EOF
# ClawUI FRP Client Configuration
# Generated at $(date)

serverAddr = "$server_addr"
serverPort = $server_port
auth.token = "$token"
transport.protocol = "$protocol"

log.to = "/var/log/frpc.log"
log.level = "$log_level"
log.maxDays = 7

EOF
    
    # Add proxies
    cat "$PROXIES_CONF" | jq -r '.[] | select(.enabled == true) | @base64' | while read proxy_b64; do
        local proxy=$(echo "$proxy_b64" | base64 -d)
        local name=$(echo "$proxy" | jq -r '.name')
        local type=$(echo "$proxy" | jq -r '.type')
        local local_ip=$(echo "$proxy" | jq -r '.local_ip')
        local local_port=$(echo "$proxy" | jq -r '.local_port')
        local remote_port=$(echo "$proxy" | jq -r '.remote_port')
        local custom_domain=$(echo "$proxy" | jq -r '.custom_domain')
        local subdomain=$(echo "$proxy" | jq -r '.subdomain')
        
        cat >> "$CLIENT_CONF" << EOF
[[proxies]]
name = "$name"
type = "$type"
localIP = "$local_ip"
localPort = $local_port
EOF
        
        case "$type" in
            tcp|udp)
                if [ "$remote_port" != "0" ] && [ -n "$remote_port" ]; then
                    echo "remotePort = $remote_port" >> "$CLIENT_CONF"
                fi
                ;;
            http|https)
                if [ -n "$custom_domain" ]; then
                    echo "customDomains = [\"$custom_domain\"]" >> "$CLIENT_CONF"
                fi
                if [ -n "$subdomain" ]; then
                    echo "subdomain = \"$subdomain\"" >> "$CLIENT_CONF"
                fi
                ;;
            stcp)
                echo "secretKey = \"$token\"" >> "$CLIENT_CONF"
                ;;
        esac
        
        echo "" >> "$CLIENT_CONF"
    done
    
    echo "Config generated at $CLIENT_CONF"
}

# Start FRP client
start_frp() {
    init_config
    
    if [ ! -x "$FRPC" ]; then
        echo '{"success": false, "message": "FRP 客户端未安装"}'
        return 1
    fi
    
    # Check if already running
    if pgrep -f "frpc" &>/dev/null; then
        echo '{"success": false, "message": "FRP 客户端已在运行"}'
        return 1
    fi
    
    # Generate config
    generate_config
    
    # Start frpc
    $FRPC -c "$CLIENT_CONF" &
    echo $! > "$PID_FILE"
    
    sleep 1
    
    if pgrep -f "frpc" &>/dev/null; then
        echo '{"success": true, "message": "FRP 客户端已启动"}'
    else
        echo '{"success": false, "message": "FRP 客户端启动失败，请检查配置"}'
    fi
}

# Stop FRP client
stop_frp() {
    if pgrep -f "frpc" &>/dev/null; then
        pkill -f "frpc"
        rm -f "$PID_FILE"
        echo '{"success": true, "message": "FRP 客户端已停止"}'
    else
        echo '{"success": false, "message": "FRP 客户端未运行"}'
    fi
}

# Restart FRP client
restart_frp() {
    stop_frp 2>/dev/null
    sleep 1
    start_frp
}

# Get FRP logs
get_logs() {
    local lines=$(echo "$QUERY_STRING" | grep -o 'lines=[0-9]*' | cut -d= -f2)
    lines=${lines:-50}
    
    if [ -f /var/log/frpc.log ]; then
        local logs=$(tail -$lines /var/log/frpc.log 2>/dev/null | jq -Rs '.')
        echo "{\"logs\": $logs}"
    else
        echo '{"logs": ""}'
    fi
}

# Test server connection
test_connection() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local server_addr=$(echo "$settings" | jq -r '.server_addr')
    local server_port=$(echo "$settings" | jq -r '.server_port')
    
    if [ -z "$server_addr" ]; then
        echo '{"success": false, "message": "服务器地址未配置"}'
        return 1
    fi
    
    # Test TCP connection
    local result="false"
    if timeout 5 bash -c "echo >/dev/tcp/$server_addr/$server_port" 2>/dev/null; then
        result="true"
    fi
    
    cat << EOF
{
    "server": "$server_addr:$server_port",
    "reachable": $result,
    "message": "$([ "$result" = "true" ] && echo '服务器可达' || echo '无法连接到服务器')"
}
EOF
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/frp/proxies/*)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/frp/proxies/||')
                cat "$PROXIES_CONF" | jq ".[] | select(.name == \"$name\")"
                ;;
            /api/apps/frp/proxies)
                list_proxies
                ;;
            /api/apps/frp/settings)
                get_settings
                ;;
            /api/apps/frp/logs)
                get_logs
                ;;
            /api/apps/frp/test)
                test_connection
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/frp/proxies)
                add_proxy
                ;;
            /api/apps/frp/proxies/*)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/frp/proxies/||')
                update_proxy "$name"
                ;;
            /api/apps/frp/settings)
                update_settings
                ;;
            /api/apps/frp/start)
                start_frp
                ;;
            /api/apps/frp/stop)
                stop_frp
                ;;
            /api/apps/frp/restart)
                restart_frp
                ;;
            /api/apps/frp/regenerate)
                generate_config
                echo '{"success": true, "message": "配置已重新生成"}'
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/frp/proxies/*)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/frp/proxies/||')
                delete_proxy "$name"
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