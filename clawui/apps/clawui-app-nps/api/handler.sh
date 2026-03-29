#!/bin/sh
# NPS Server API Handler

ACTION="$1"
shift

NPS_BIN="/usr/bin/nps"
NPS_CONFIG="/etc/nps/nps.conf"
NPS_LOG="/var/log/nps.log"

case "$ACTION" in
    start)
        if [ -x "$NPS_BIN" ]; then
            $NPS_BIN start 2>/dev/null
            echo '{"success": true}'
        else
            echo '{"success": false, "error": "NPS binary not found. Install with: apk add nps"}'
        fi
        ;;
    
    stop)
        if [ -x "$NPS_BIN" ]; then
            $NPS_BIN stop 2>/dev/null
            echo '{"success": true}'
        else
            echo '{"success": false, "error": "NPS binary not found"}'
        fi
        ;;
    
    restart)
        if [ -x "$NPS_BIN" ]; then
            $NPS_BIN restart 2>/dev/null
            echo '{"success": true}'
        else
            echo '{"success": false, "error": "NPS binary not found"}'
        fi
        ;;
    
    status)
        if pgrep -f "nps" > /dev/null 2>&1; then
            RUNNING="true"
        else
            RUNNING="false"
        fi
        
        # Read config
        HTTP_PORT="80"
        HTTPS_PORT="443"
        CLIENT_PORT="8024"
        WEB_PORT="8080"
        WEB_USER="admin"
        
        if [ -f "$NPS_CONFIG" ]; then
            HTTP_PORT=$(grep "^http_proxy_port=" "$NPS_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            HTTPS_PORT=$(grep "^https_proxy_port=" "$NPS_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            CLIENT_PORT=$(grep "^bridge_port=" "$NPS_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            WEB_PORT=$(grep "^web_port=" "$NPS_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            WEB_USER=$(grep "^web_username=" "$NPS_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
        fi
        
        # NPS has a local API on web_port, but we'll return mock stats for now
        echo "{\"running\": ${RUNNING}, \"config\": {\"http_port\": ${HTTP_PORT:-80}, \"https_port\": ${HTTPS_PORT:-443}, \"client_port\": ${CLIENT_PORT:-8024}, \"web_port\": ${WEB_PORT:-8080}, \"web_user\": \"${WEB_USER:-admin}\"}, \"stats\": {\"clients\": 0, \"online\": 0, \"tunnels\": 0, \"traffic\": 0}}"
        ;;
    
    config)
        read -r INPUT
        HTTP_PORT=$(echo "$INPUT" | sed -n 's/.*"http_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        HTTPS_PORT=$(echo "$INPUT" | sed -n 's/.*"https_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        CLIENT_PORT=$(echo "$INPUT" | sed -n 's/.*"client_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        WEB_PORT=$(echo "$INPUT" | sed -n 's/.*"web_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        WEB_USER=$(echo "$INPUT" | sed -n 's/.*"web_user"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        WEB_PASS=$(echo "$INPUT" | sed -n 's/.*"web_pass"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        
        # Update config file
        cat > "$NPS_CONFIG" << EOF
# NPS Server Configuration - Managed by ClawUI
http_proxy_port=${HTTP_PORT:-80}
https_proxy_port=${HTTPS_PORT:-443}
bridge_port=${CLIENT_PORT:-8024}
web_port=${WEB_PORT:-8080}
web_username=${WEB_USER:-admin}
${WEB_PASS:+web_password=${WEB_PASS}}
EOF
        echo '{"success": true}'
        ;;
    
    clients)
        # NPS stores clients in database, return empty for now
        # In production, would query NPS API
        echo '{"clients": []}'
        ;;
    
    log)
        if [ -f "$NPS_LOG" ]; then
            LOG=$(tail -100 "$NPS_LOG" 2>/dev/null | tr '\n' '\\n' | tr '"' "'")
        else
            LOG="No log file found. Make sure NPS is installed."
        fi
        echo "{\"log\": \"${LOG}\"}"
        ;;
    
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
