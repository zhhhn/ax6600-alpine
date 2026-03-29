#!/bin/sh
# AdGuard Home API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/adguardhome start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/adguardhome stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "AdGuardHome" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}, \"stats\": {\"queries\": 0, \"blocked\": 0, \"percent\": 0}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
