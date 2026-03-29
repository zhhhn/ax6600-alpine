#!/bin/sh
# PhotoPrism API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/photoprism start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/photoprism stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "photoprism" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
