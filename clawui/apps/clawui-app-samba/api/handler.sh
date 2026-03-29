#!/bin/sh
# Samba API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/smbd start 2>/dev/null; /etc/init.d/nmbd start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/smbd stop 2>/dev/null; /etc/init.d/nmbd stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "smbd" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    shares) echo '{"shares": []}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
