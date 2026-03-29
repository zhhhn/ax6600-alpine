#!/bin/sh
# ClawUI WireGuard App API
# WireGuard VPN management

WG_CONF_DIR="/etc/wireguard"
WG_TOOL="/usr/bin/wg"
WG_QUICK="/usr/bin/wg-quick"

# Get WireGuard status
get_status() {
    local enabled="false"
    local running="false"
    local interfaces="[]"
    
    # Check if WireGuard is installed
    if command -v wg &>/dev/null; then
        # Check running interfaces
        interfaces=$(wg show 2>/dev/null | grep -E "^interface:" | awk '{print $2}' | jq -R -s 'split("\n") | map(select(length > 0))')
        
        if [ -n "$interfaces" ] && [ "$interfaces" != "[]" ]; then
            running="true"
        fi
    fi
    
    # Check if enabled
    if [ -f /etc/init.d/wireguard ] && rc-service wireguard status 2>/dev/null | grep -q started; then
        enabled="true"
    fi
    
    cat << EOF
{
    "installed": $(command -v wg &>/dev/null && echo 'true' || echo 'false'),
    "enabled": $enabled,
    "running": $running,
    "interfaces": $interfaces
}
EOF
}

# List interfaces
list_interfaces() {
    echo "["
    
    if [ -d "$WG_CONF_DIR" ]; then
        local first=1
        for conf in "$WG_CONF_DIR"/*.conf; do
            [ -f "$conf" ] || continue
            
            local name=$(basename "$conf" .conf)
            local public_key=$(wg show "$name" public-key 2>/dev/null || echo "")
            local listen_port=$(grep ListenPort "$conf" 2>/dev/null | awk '{print $3}')
            local peers=$(wg show "$name" peers 2>/dev/null | wc -l)
            
            [ "$first" = "0" ] && echo ","
            first=0
            
            cat << EOF
{
    "name": "$name",
    "public_key": "$public_key",
    "listen_port": ${listen_port:-51820},
    "peers": $peers,
    "config_file": "$conf"
}
EOF
        done
    fi
    
    echo "]"
}

# Get interface details
get_interface() {
    local name="$1"
    local conf="$WG_CONF_DIR/$name.conf"
    
    if [ ! -f "$conf" ]; then
        echo '{"error": "Interface not found"}'
        return 1
    fi
    
    # Parse config
    local private_key=$(grep PrivateKey "$conf" | cut -d= -f2- | tr -d ' ')
    local listen_port=$(grep ListenPort "$conf" | awk '{print $3}')
    local address=$(grep Address "$conf" | cut -d= -f2- | tr -d ' ')
    local dns=$(grep DNS "$conf" | cut -d= -f2- | tr -d ' ')
    
    # Get runtime info
    local public_key=$(wg show "$name" public-key 2>/dev/null || echo "")
    local peers=$(wg show "$name" peers 2>/dev/null | wc -l)
    
    cat << EOF
{
    "name": "$name",
    "private_key": "***",
    "public_key": "$public_key",
    "listen_port": ${listen_port:-51820},
    "address": "$address",
    "dns": "$dns",
    "peers": $peers,
    "config": $(cat "$conf" | jq -Rs '.')
}
EOF
}

# Create interface
create_interface() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local address=$(echo "$data" | jq -r '.address')
    local port=$(echo "$data" | jq -r '.port // 51820')
    
    if [ -z "$name" ] || [ -z "$address" ]; then
        echo '{"success": false, "message": "Name and address required"}'
        return 1
    fi
    
    # Generate keys
    local private_key=$(wg genkey)
    local public_key=$(echo "$private_key" | wg pubkey)
    
    # Create config
    mkdir -p "$WG_CONF_DIR"
    cat > "$WG_CONF_DIR/$name.conf" << EOF
[Interface]
PrivateKey = $private_key
Address = $address
ListenPort = $port

[Peer]
# Add peer config here
EOF
    
    chmod 600 "$WG_CONF_DIR/$name.conf"
    
    echo "{\"success\": true, \"message\": \"Interface $name created\", \"public_key\": \"$public_key\"}"
}

# Add peer
add_peer() {
    local name="$1"
    read -n $CONTENT_LENGTH data
    
    local peer_pubkey=$(echo "$data" | jq -r '.public_key')
    local peer_ip=$(echo "$data" | jq -r '.allowed_ips // "0.0.0.0/0"')
    local endpoint=$(echo "$data" | jq -r '.endpoint // ""')
    
    if [ -z "$peer_pubkey" ]; then
        echo '{"success": false, "message": "Public key required"}'
        return 1
    fi
    
    # Add peer to config
    local conf="$WG_CONF_DIR/$name.conf"
    if [ ! -f "$conf" ]; then
        echo '{"success": false, "message": "Interface not found"}'
        return 1
    fi
    
    echo "" >> "$conf"
    echo "[Peer]" >> "$conf"
    echo "PublicKey = $peer_pubkey" >> "$conf"
    echo "AllowedIPs = $peer_ip" >> "$conf"
    [ -n "$endpoint" ] && echo "Endpoint = $endpoint" >> "$conf"
    
    echo "{\"success\": true, \"message\": \"Peer added\"}"
}

# Delete interface
delete_interface() {
    local name="$1"
    local conf="$WG_CONF_DIR/$name.conf"
    
    if [ -f "$conf" ]; then
        wg-quick down "$name" 2>/dev/null || true
        rm -f "$conf"
        echo "{\"success\": true, \"message\": \"Interface $name deleted\"}"
    else
        echo '{"success": false, "message": "Interface not found"}'
    fi
}

# Toggle interface
toggle_interface() {
    local name="$1"
    read -n $CONTENT_LENGTH data
    local action=$(echo "$data" | jq -r '.action')
    
    case "$action" in
        up)
            wg-quick up "$name" 2>/dev/null && \
                echo "{\"success\": true, \"message\": \"$name started\"}" || \
                echo "{\"success\": false, \"message\": \"Failed to start $name\"}"
            ;;
        down)
            wg-quick down "$name" 2>/dev/null && \
                echo "{\"success\": true, \"message\": \"$name stopped\"}" || \
                echo "{\"success\": false, \"message\": \"Failed to stop $name\"}"
            ;;
    esac
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/wireguard/interfaces)
                list_interfaces
                ;;
            /api/apps/wireguard/interfaces/*)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/wireguard/interfaces/||')
                get_interface "$name"
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        case "$PATH_INFO" in
            /api/apps/wireguard/interfaces)
                create_interface
                ;;
            /api/apps/wireguard/interfaces/*/peers)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/wireguard/interfaces/\([^/]*\)/peers|\1|')
                add_peer "$name"
                ;;
            /api/apps/wireguard/interfaces/*/toggle)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/wireguard/interfaces/\([^/]*\)/toggle|\1|')
                toggle_interface "$name"
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        local name=$(echo "$PATH_INFO" | sed 's|/api/apps/wireguard/interfaces/||')
        delete_interface "$name"
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac