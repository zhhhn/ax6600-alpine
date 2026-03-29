#!/bin/sh
# NPS Client API

ACTION="$1"
shift

NPS_CONFIG="/etc/nps/npc.conf"

case "$ACTION" in
    start)
        /etc/init.d/nps-client start
        echo '{"success": true}'
        ;;
    stop)
        /etc/init.d/nps-client stop
        echo '{"success": true}'
        ;;
    status)
        if pgrep -f "npc" > /dev/null; then
            echo '{"running": true}'
        else
            echo '{"running": false}'
        fi
        ;;
    config)
        read -r JSON
        SERVER_ADDR=$(echo "$JSON" | grep -o '"server_addr":"[^"]*"' | cut -d'"' -f4)
        SERVER_PORT=$(echo "$JSON" | grep -o '"server_port":[0-9]*' | cut -d: -f2)
        VKEY=$(echo "$JSON" | grep -o '"vkey":"[^"]*"' | cut -d'"' -f4)
        CONFIG_PATH=$(echo "$JSON" | grep -o '"config_path":"[^"]*"' | cut -d'"' -f4)
        
        mkdir -p /etc/nps
        cat > "$NPS_CONFIG" << EOF
server_addr=${SERVER_ADDR}
server_port=${SERVER_PORT}
vkey=${VKEY}
conn_type=tcp
auto_reconnect=true
EOF
        echo '{"success": true}'
        ;;
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
