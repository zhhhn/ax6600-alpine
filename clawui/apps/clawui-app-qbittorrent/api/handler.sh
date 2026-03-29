#!/bin/sh
# qBittorrent API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/qbittorrent-nox start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/qbittorrent-nox stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "qbittorrent" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    add) read -r INPUT; URL=$(echo "$INPUT" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'); curl -s -X POST http://localhost:8080/api/v2/torrents/add --data-urlencode "urls=$URL" 2>/dev/null; echo '{"success": true}' ;;
    torrents) echo '{"torrents": []}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
