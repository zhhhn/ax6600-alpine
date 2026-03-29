#!/bin/sh
# Nginx API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/nginx start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/nginx stop 2>/dev/null; echo '{"success": true}' ;;
    reload) /etc/init.d/nginx reload 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "nginx" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
