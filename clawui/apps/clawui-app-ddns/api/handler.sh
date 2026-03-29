#!/bin/sh
# DDNS API Handler
ACTION="$1"; shift
DDNS_CONF="/etc/ddns/config"
case "$ACTION" in
    start) /etc/init.d/ddns start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/ddns stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "ddns" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    config)
        read -r INPUT
        PROVIDER=$(echo "$INPUT" | sed -n 's/.*"provider"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        DOMAIN=$(echo "$INPUT" | sed -n 's/.*"domain"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        APIKEY=$(echo "$INPUT" | sed -n 's/.*"apikey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        mkdir -p /etc/ddns
        cat > "$DDNS_CONF" << EOF
PROVIDER=$PROVIDER
DOMAIN=$DOMAIN
APIKEY=$APIKEY
EOF
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
