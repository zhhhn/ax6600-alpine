#!/bin/sh
# Syncthing API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/syncthing start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/syncthing stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "syncthing" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}, \"info\": {\"status\": \"$([ "$RUNNING" = "true" ] && echo 'Running' || echo 'Stopped')\"}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
