#!/bin/sh
# OpenVPN API Handler
ACTION="$1"; shift
OVPN_CONF="/etc/openvpn/client.conf"
case "$ACTION" in
    start)
        if [ -f "$OVPN_CONF" ]; then
            /etc/init.d/openvpn start 2>/dev/null
            echo '{"success": true}'
        else
            echo '{"success": false, "error": "Config not found"}'
        fi
        ;;
    stop) /etc/init.d/openvpn stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "openvpn" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    config)
        read -r INPUT
        CFG=$(echo "$INPUT" | sed -n 's/.*"config"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        mkdir -p /etc/openvpn
        echo "$CFG" > "$OVPN_CONF"
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
