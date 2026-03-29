#!/bin/sh
# Shadowsocks API Handler
ACTION="$1"; shift
SS_CONFIG="/etc/shadowsocks-libev/config.json"
case "$ACTION" in
    start) /etc/init.d/shadowsocks-libev start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/shadowsocks-libev stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "ss-local" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    config)
        read -r INPUT
        SERVER=$(echo "$INPUT" | sed -n 's/.*"server"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        PORT=$(echo "$INPUT" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        PASS=$(echo "$INPUT" | sed -n 's/.*"password"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        METHOD=$(echo "$INPUT" | sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        LPORT=$(echo "$INPUT" | sed -n 's/.*"local_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        mkdir -p /etc/shadowsocks-libev
        cat > "$SS_CONFIG" << EOF
{
    "server": "$SERVER",
    "server_port": $PORT,
    "password": "$PASS",
    "method": "$METHOD",
    "local_port": $LPORT
}
EOF
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
