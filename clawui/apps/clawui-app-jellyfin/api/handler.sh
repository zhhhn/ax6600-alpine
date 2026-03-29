#!/bin/sh
# Jellyfin API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/jellyfin start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/jellyfin stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "jellyfin" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
