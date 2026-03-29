#!/bin/sh
# FRP Client API Handler

ACTION="$1"
shift

FRPC_BIN="/usr/bin/frpc"
FRPC_CONFIG="/etc/frp/frpc.ini"
FRPC_LOG="/var/log/frpc.log"

case "$ACTION" in
    start)
        if [ -x "$FRPC_BIN" ] && [ -f "$FRPC_CONFIG" ]; then
            $FRPC_BIN -c "$FRPC_CONFIG" > /dev/null 2>&1 &
            echo '{"success": true}'
        else
            echo '{"success": false, "error": "FRPC binary or config not found"}'
        fi
        ;;
    stop)
        pkill -f "frpc" 2>/dev/null
        echo '{"success": true}'
        ;;
    status)
        if pgrep -f "frpc" > /dev/null 2>&1; then
            RUNNING="true"
        else
            RUNNING="false"
        fi
        SERVER_ADDR=$(grep "^server_addr=" "$FRPC_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
        SERVER_PORT=$(grep "^server_port=" "$FRPC_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
        TOKEN=$(grep "^token=" "$FRPC_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
        echo "{\"running\": ${RUNNING}, \"config\": {\"server_addr\": \"${SERVER_ADDR}\", \"server_port\": \"${SERVER_PORT:-7000}\", \"token\": \"${TOKEN}\"}}"
        ;;
    config)
        read -r INPUT
        SERVER_ADDR=$(echo "$INPUT" | sed -n 's/.*"server_addr"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        SERVER_PORT=$(echo "$INPUT" | sed -n 's/.*"server_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        TOKEN=$(echo "$INPUT" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        mkdir -p /etc/frp
        cat > "$FRPC_CONFIG" << EOF
[common]
server_addr=${SERVER_ADDR}
server_port=${SERVER_PORT}
token=${TOKEN}
EOF
        echo '{"success": true}'
        ;;
    proxies)
        echo '{"proxies": []}'
        ;;
    log)
        if [ -f "$FRPC_LOG" ]; then
            LOG=$(tail -100 "$FRPC_LOG" 2>/dev/null | tr '\n' '\\n' | tr '"' "'")
        else
            LOG="No log file"
        fi
        echo "{\"log\": \"${LOG}\"}"
        ;;
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
