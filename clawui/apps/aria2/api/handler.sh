#!/bin/sh
# Aria2 API

ACTION="$1"
shift

ARIA2_CONFIG="/etc/aria2/aria2.conf"

case "$ACTION" in
    start)
        /etc/init.d/aria2 start
        echo '{"success": true}'
        ;;
    stop)
        /etc/init.d/aria2 stop
        echo '{"success": true}'
        ;;
    status)
        if pgrep -f "aria2c" > /dev/null; then
            PORT=$(grep -E "^rpc-listen-port=" /etc/aria2/aria2.conf 2>/dev/null | cut -d= -f2)
            echo "{\"running\": true, \"port\": ${PORT:-6800}}"
        else
            echo '{"running": false}'
        fi
        ;;
    tasks)
        # Get active downloads via aria2c RPC
        if command -v curl >/dev/null; then
            SECRET=$(grep -E "^rpc-secret=" /etc/aria2/aria2.conf 2>/dev/null | cut -d= -f2)
            curl -s -X POST http://localhost:6800/jsonrpc \
                -H "Content-Type: application/json" \
                -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"aria2.tellActive\",\"params\":[\"token:${SECRET:-}\"]}" 2>/dev/null || \
            echo '{"tasks": []}'
        else
            echo '{"tasks": []}'
        fi
        ;;
    add)
        read -r JSON
        URL=$(echo "$JSON" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        SECRET=$(grep -E "^rpc-secret=" /etc/aria2/aria2.conf 2>/dev/null | cut -d= -f2)
        
        curl -s -X POST http://localhost:6800/jsonrpc \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"aria2.addUri\",\"params\":[\"token:${SECRET:-}\",[\"${URL}\"]]}" 2>/dev/null || \
        echo '{"success": false, "error": "Failed to add download"}'
        ;;
    config)
        read -r JSON
        RPC_PORT=$(echo "$JSON" | grep -o '"rpc_port":[0-9]*' | cut -d: -f2)
        DOWNLOAD_DIR=$(echo "$JSON" | grep -o '"download_dir":"[^"]*"' | cut -d'"' -f4)
        MAX_CONN=$(echo "$JSON" | grep -o '"max_connections":[0-9]*' | cut -d: -f2)
        RPC_SECRET=$(echo "$JSON" | grep -o '"rpc_secret":"[^"]*"' | cut -d'"' -f4)
        
        cat > "$ARIA2_CONFIG" << EOF
# Aria2 configuration
dir=${DOWNLOAD_DIR:-/var/lib/aria2/downloads}
rpc-listen-port=${RPC_PORT:-6800}
max-connection-per-server=${MAX_CONN:-16}
rpc-secret=${RPC_SECRET:-}
enable-rpc=true
rpc-allow-origin-all=true
continue=true
EOF
        echo '{"success": true}'
        ;;
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
