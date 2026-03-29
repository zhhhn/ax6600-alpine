#!/bin/sh
# Mosquitto MQTT API Handler
ACTION="$1"; shift
MOSQUITTO_CONF="/etc/mosquitto/mosquitto.conf"
case "$ACTION" in
    start) /etc/init.d/mosquitto start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/mosquitto stop 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "mosquitto" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}, \"stats\": {\"clients\": 0, \"messages\": 0}}"
        ;;
    config)
        read -r INPUT
        PORT=$(echo "$INPUT" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        WS_PORT=$(echo "$INPUT" | sed -n 's/.*"ws_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        ANON=$(echo "$INPUT" | sed -n 's/.*"anonymous"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        cat > "$MOSQUITTO_CONF" << EOF
listener $PORT
listener $WS_PORT
protocol websockets
allow_anonymous $ANON
EOF
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
