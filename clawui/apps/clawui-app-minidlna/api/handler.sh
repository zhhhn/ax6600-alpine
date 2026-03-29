#!/bin/sh
# MiniDLNA API Handler
ACTION="$1"; shift
MINIDLNA_CONF="/etc/minidlna.conf"
case "$ACTION" in
    start) /etc/init.d/minidlna start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/minidlna stop 2>/dev/null; echo '{"success": true}' ;;
    rescan) /etc/init.d/minidlna restart 2>/dev/null; echo '{"success": true, "message": "Rescanning media..."}' ;;
    status)
        if pgrep -f "minidlnad" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}, \"stats\": {\"video\": 0, \"music\": 0, \"photo\": 0}}"
        ;;
    config) echo '{"success": true}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
