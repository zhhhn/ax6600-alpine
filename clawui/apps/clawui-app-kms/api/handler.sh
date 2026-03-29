#!/bin/sh
# KMS Manager API Handler

ACTION="$1"
shift

KMS_CONFIG="/etc/conf.d/kms-server"
KMS_LOG="/var/log/kms-server.log"

case "$ACTION" in
    start)
        /etc/init.d/kms-server start 2>/dev/null || /etc/init.d/py-kms start 2>/dev/null
        echo '{"success": true}'
        ;;
    
    stop)
        /etc/init.d/kms-server stop 2>/dev/null || /etc/init.d/py-kms stop 2>/dev/null
        echo '{"success": true}'
        ;;
    
    status)
        if pgrep -f "kms\|py-kms" > /dev/null 2>&1; then
            RUNNING="true"
        else
            RUNNING="false"
        fi
        
        PORT="1688"
        if [ -f "$KMS_CONFIG" ]; then
            PORT=$(grep "^PORT=" "$KMS_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
        fi
        
        echo "{\"running\": ${RUNNING}, \"config\": {\"port\": ${PORT:-1688}}, \"stats\": {\"requests\": 0, \"success\": 0}}"
        ;;
    
    config)
        read -r INPUT
        PORT=$(echo "$INPUT" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        
        mkdir -p /etc/conf.d
        cat > "$KMS_CONFIG" << EOF
PORT=${PORT:-1688}
EOF
        echo '{"success": true}'
        ;;
    
    log)
        if [ -f "$KMS_LOG" ]; then
            LOG=$(tail -100 "$KMS_LOG" 2>/dev/null | tr '\n' '\\n' | tr '"' "'")
        else
            LOG="No log file found. Make sure py-kms or kms-server is installed."
        fi
        echo "{\"log\": \"${LOG}\"}"
        ;;
    
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
