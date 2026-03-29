#!/bin/sh
# KMS Server API

ACTION="$1"
shift

case "$ACTION" in
    start)
        /etc/init.d/kms-server start
        echo '{"success": true}'
        ;;
    stop)
        /etc/init.d/kms-server stop
        echo '{"success": true}'
        ;;
    status)
        if pgrep -f "kms-server.sh" > /dev/null; then
            PORT=$(grep -E "^PORT=" /etc/conf.d/kms-server 2>/dev/null | cut -d= -f2)
            echo "{\"running\": true, \"port\": ${PORT:-1688}}"
        else
            echo '{"running": false}'
        fi
        ;;
    config)
        # Read JSON from stdin
        read -r JSON
        PORT=$(echo "$JSON" | grep -o '"port":[0-9]*' | cut -d: -f2)
        INTERVAL=$(echo "$JSON" | grep -o '"interval":[0-9]*' | cut -d: -f2)
        
        cat > /etc/conf.d/kms-server << EOF
PORT=${PORT:-1688}
ACTIVATION_INTERVAL=${INTERVAL:-259200}
EOF
        echo '{"success": true}'
        ;;
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
