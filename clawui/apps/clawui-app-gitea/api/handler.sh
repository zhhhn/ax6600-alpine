#!/bin/sh
# Gitea API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/gitea start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/gitea stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "gitea" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
