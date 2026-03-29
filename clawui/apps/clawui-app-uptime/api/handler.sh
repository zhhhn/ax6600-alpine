#!/bin/sh
# Uptime Kuma API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/uptime-kuma start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/uptime-kuma stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "uptime-kuma" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
