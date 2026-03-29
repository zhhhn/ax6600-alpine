#!/bin/sh
# ZeroTier API Handler
ACTION="$1"; shift
ZT_STATUS="/var/lib/zerotier-one/status"
case "$ACTION" in
    start) /etc/init.d/zerotier-one start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/zerotier-one stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "zerotier-one" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}, \"networks\": []}"
        ;;
    join)
        read -r INPUT
        NET_ID=$(echo "$INPUT" | sed -n 's/.*"network_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        zerotier-cli join "$NET_ID" 2>/dev/null
        echo '{"success": true}'
        ;;
    leave)
        read -r INPUT
        NET_ID=$(echo "$INPUT" | sed -n 's/.*"network_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        zerotier-cli leave "$NET_ID" 2>/dev/null
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
