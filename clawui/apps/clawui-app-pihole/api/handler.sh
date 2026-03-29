#!/bin/sh
# Pi-hole API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) pihole enable 2>/dev/null; echo '{"success": true}' ;;
    stop) pihole disable 2>/dev/null; echo '{"success": true}' ;;
    disable) pihole disable 60 2>/dev/null; echo '{"success": true, "message": "Disabled for 60s"}' ;;
    status)
        if pgrep -f "pihole-FTL" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}, \"stats\": {\"queries\": 0, \"blocked\": 0, \"percent\": 0}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
