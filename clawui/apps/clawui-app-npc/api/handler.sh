#!/bin/sh
# NPC Client API Handler

ACTION="$1"
shift

NPC_BIN="/usr/bin/npc"
NPC_CONFIG="/etc/nps/npc.conf"
NPC_LOG="/var/log/npc.log"

case "$ACTION" in
    start)
        if [ -x "$NPC_BIN" ] && [ -f "$NPC_CONFIG" ]; then
            $NPC_BIN -config="$NPC_CONFIG" -daemon=1 2>/dev/null
            echo '{"success": true}'
        else
            echo '{"success": false, "error": "NPC binary or config not found"}'
        fi
        ;;
    
    stop)
        pkill -f "npc.*-config" 2>/dev/null
        echo '{"success": true}'
        ;;
    
    restart)
        pkill -f "npc.*-config" 2>/dev/null
        sleep 1
        if [ -x "$NPC_BIN" ] && [ -f "$NPC_CONFIG" ]; then
            $NPC_BIN -config="$NPC_CONFIG" -daemon=1 2>/dev/null
        fi
        echo '{"success": true}'
        ;;
    
    status)
        if pgrep -f "npc.*-config" > /dev/null 2>&1; then
            RUNNING="true"
        else
            RUNNING="false"
        fi
        
        # Read config
        SERVER_ADDR=""
        SERVER_PORT="8024"
        VKEY=""
        CONN_TYPE="tcp"
        
        if [ -f "$NPC_CONFIG" ]; then
            SERVER_ADDR=$(grep "^server_addr=" "$NPC_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            SERVER_PORT=$(grep "^server_port=" "$NPC_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            VKEY=$(grep "^vkey=" "$NPC_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            CONN_TYPE=$(grep "^conn_type=" "$NPC_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
        fi
        
        echo "{\"running\": ${RUNNING}, \"config\": {\"server_addr\": \"${SERVER_ADDR}\", \"server_port\": \"${SERVER_PORT}\", \"vkey\": \"${VKEY}\", \"conn_type\": \"${CONN_TYPE}\"}}"
        ;;
    
    config)
        read -r INPUT
        SERVER_ADDR=$(echo "$INPUT" | sed -n 's/.*"server_addr"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        SERVER_PORT=$(echo "$INPUT" | sed -n 's/.*"server_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        VKEY=$(echo "$INPUT" | sed -n 's/.*"vkey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        CONN_TYPE=$(echo "$INPUT" | sed -n 's/.*"conn_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        
        mkdir -p /etc/nps
        cat > "$NPC_CONFIG" << EOF
server_addr=${SERVER_ADDR}
server_port=${SERVER_PORT}
vkey=${VKEY}
conn_type=${CONN_TYPE:-tcp}
auto_reconnect=true
EOF
        echo '{"success": true}'
        ;;
    
    tunnels)
        # NPC doesn't expose tunnel info locally, return empty
        # Tunnels are configured on NPS server side
        echo '{"tunnels": []}'
        ;;
    
    log)
        if [ -f "$NPC_LOG" ]; then
            LOG=$(tail -100 "$NPC_LOG" 2>/dev/null | tr '\n' '\\n' | tr '"' "'")
        else
            LOG="No log file found. Make sure NPC is installed and running."
        fi
        echo "{\"log\": \"${LOG}\"}"
        ;;
    
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
