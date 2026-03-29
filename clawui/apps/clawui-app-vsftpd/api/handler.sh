#!/bin/sh
# Vsftpd API Handler
ACTION="$1"; shift
VSFTPD_CONFIG="/etc/vsftpd/vsftpd.conf"
case "$ACTION" in
    start) /etc/init.d/vsftpd start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/vsftpd stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "vsftpd" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    config) echo '{"success": true}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
