#!/bin/sh
# Tiny Tiny RSS API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) /etc/init.d/php-fpm start 2>/dev/null; /etc/init.d/postgresql start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/php-fpm stop 2>/dev/null; /etc/init.d/postgresql stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "php-fpm" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
