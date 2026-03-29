#!/bin/sh
# File Browser API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/filebrowser start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/filebrowser stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "filebrowser" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    config) echo '{"success": true}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
