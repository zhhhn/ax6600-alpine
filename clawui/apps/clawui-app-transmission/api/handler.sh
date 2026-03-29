#!/bin/sh
# Transmission API Handler
ACTION="$1"; shift
TRANSMISSION_CONFIG="/etc/transmission/settings.json"
case "$ACTION" in
    start) /etc/init.d/transmission start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/transmission stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "transmission-daemon" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    config)
        read -r INPUT
        DIR=$(echo "$INPUT" | sed -n 's/.*"download_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        PORT=$(echo "$INPUT" | sed -n 's/.*"rpc_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        echo '{"success": true}'
        ;;
    torrents) echo '{"torrents": []}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
