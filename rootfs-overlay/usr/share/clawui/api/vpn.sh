#!/bin/sh
# ClawUI VPN API
# OpenVPN and WireGuard configuration

# Get VPN status
get_vpn_status() {
    local openvpn="disconnected"
    local wireguard="disconnected"
    
    # Check OpenVPN
    if ip addr show tun0 2>/dev/null | grep -q inet; then
        openvpn="connected"
    fi
    
    # Check WireGuard
    if command -v wg &>/dev/null && wg show 2>/dev/null | grep -q peer; then
        wireguard="connected"
    fi
    
    cat << EOF
{
    "openvpn": {
        "status": "$openvpn",
        "config_exists": $([ -f /etc/vpn/openvpn/client.conf ] && echo 'true' || echo 'false')
    },
    "wireguard": {
        "status": "$wireguard",
        "config_exists": $([ -f /etc/vpn/wireguard/*.conf ] && echo 'true' || echo 'false')
    }
}
EOF
}

# Configure OpenVPN
config_openvpn() {
    read -n $CONTENT_LENGTH data
    
    local server=$(echo "$data" | grep -o '"server":"[^"]*"' | cut -d'"' -f4)
    local port=$(echo "$data" | grep -o '"port":[0-9]*' | cut -d: -f2)
    local proto=$(echo "$data" | grep -o '"proto":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$server" ]; then
        /usr/sbin/vpn-setup openvpn config "$server" "${port:-1194}" "${proto:-udp}"
        echo '{"success": true}'
    else
        echo '{"success": false}'
    fi
}

# Configure WireGuard
config_wireguard() {
    read -n $CONTENT_LENGTH data
    
    local interface=$(echo "$data" | grep -o '"interface":"[^"]*"' | cut -d'"' -f4)
    local endpoint=$(echo "$data" | grep -o '"endpoint":"[^"]*"' | cut -d'"' -f4)
    local pubkey=$(echo "$data" | grep -o '"pubkey":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$interface" ] && [ -n "$endpoint" ]; then
        /usr/sbin/vpn-setup wireguard config "$interface" "$endpoint"
        echo '{"success": true}'
    else
        echo '{"success": false}'
    fi
}

# Start/Stop VPN
toggle_vpn() {
    read -n $CONTENT_LENGTH data
    
    local type=$(echo "$data" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    local action=$(echo "$data" | grep -o '"action":"[^"]*"' | cut -d'"' -f4)
    
    case "$type" in
        openvpn)
            case "$action" in
                start) /usr/sbin/vpn-setup openvpn start ;;
                stop) /usr/sbin/vpn-setup openvpn stop ;;
            esac
            ;;
        wireguard)
            case "$action" in
                start) /usr/sbin/vpn-setup wireguard start ;;
                stop) /usr/sbin/vpn-setup wireguard stop ;;
            esac
            ;;
    esac
    
    echo '{"success": true}'
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        get_vpn_status
        ;;
    POST)
        case "$PATH_INFO" in
            /api/vpn/openvpn)
                config_openvpn
                ;;
            /api/vpn/wireguard)
                config_wireguard
                ;;
            /api/vpn/toggle)
                toggle_vpn
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