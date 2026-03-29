#!/bin/sh
# WireGuard API Handler
ACTION="$1"; shift
WG_CONF="/etc/wireguard/wg0.conf"
case "$ACTION" in
    start) wg-quick up wg0 2>/dev/null; echo '{"success": true}' ;;
    stop) wg-quick down wg0 2>/dev/null; echo '{"success": true}' ;;
    status)
        if ip link show wg0 > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    add-peer)
        read -r INPUT
        NAME=$(echo "$INPUT" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        wg genkey | tee /tmp/${NAME}_private.key | wg pubkey > /tmp/${NAME}_public.key
        echo "配置文件已生成：/tmp/${NAME}_private.key"
        echo '{"success": true}'
        ;;
    peers) echo '{"peers": []}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
