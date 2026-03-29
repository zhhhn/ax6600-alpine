#!/bin/sh
# Aria2 Manager API Handler

ACTION="$1"
shift

ARIA2_RPC="http://localhost:6800/jsonrpc"
ARIA2_CONFIG="/etc/aria2/aria2.conf"
ARIA2_LOG="/var/log/aria2.log"

# Get RPC secret from config
get_rpc_secret() {
    grep -E "^rpc-secret=" "$ARIA2_CONFIG" 2>/dev/null | cut -d= -f2 | head -1
}

# Call aria2 RPC
rpc_call() {
    local method="$1"
    local params="$2"
    local secret=$(get_rpc_secret)
    
    if [ -n "$secret" ]; then
        curl -s -X POST "$ARIA2_RPC" \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"aria2.${method}\",\"params\":[\"token:${secret}\"]${params}}"
    else
        curl -s -X POST "$ARIA2_RPC" \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"aria2.${method}\",\"params\":[${params}]}"
    fi
}

case "$ACTION" in
    start)
        /etc/init.d/aria2 start 2>/dev/null
        echo '{"success": true, "message": "Aria2 service started"}'
        ;;
    
    stop)
        /etc/init.d/aria2 stop 2>/dev/null
        echo '{"success": true, "message": "Aria2 service stopped"}'
        ;;
    
    restart)
        /etc/init.d/aria2 restart 2>/dev/null
        echo '{"success": true, "message": "Aria2 service restarted"}'
        ;;
    
    status)
        if pgrep -f "aria2c" > /dev/null 2>&1; then
            # Get RPC port from config
            PORT=$(grep -E "^rpc-listen-port=" "$ARIA2_CONFIG" 2>/dev/null | cut -d= -f2 | head -1)
            echo "{\"running\": true, \"port\": ${PORT:-6800}}"
        else
            echo '{"running": false}'
        fi
        ;;
    
    tasks)
        # Get active downloads
        ACTIVE=$(rpc_call "tellActive" ",{\"key\":\"gid\",\"key\":\"files\",\"key\":\"totalLength\",\"key\":\"completedLength\",\"key\":\"uploadSpeed\",\"key\":\"downloadSpeed\",\"key\":\"status\",\"key\":\"numSeeders\"}" 2>/dev/null)
        
        # Get waiting downloads
        WAITING=$(rpc_call "tellWaiting" ",0,100,{\"key\":\"gid\",\"key\":\"files\",\"key\":\"totalLength\",\"key\":\"completedLength\",\"key\":\"status\"}" 2>/dev/null)
        
        # Get stopped (complete) downloads
        STOPPED=$(rpc_call "tellStopped" ",0,100,{\"key\":\"gid\",\"key\":\"files\",\"key\":\"totalLength\",\"key\":\"completedLength\",\"key\":\"status\"}" 2>/dev/null)
        
        # Combine and format
        if command -v jq > /dev/null 2>&1; then
            # Use jq if available
            TASKS=$(echo "{\"active\":${ACTIVE:-[]},\"waiting\":${WAITING:-[]},\"stopped\":${STOPPED:-[]}}" | jq -c '
                [.active[], .waiting[], .stopped[]] | map({
                    gid: .gid,
                    name: (.files[0].path | split("/")[-1] // "unknown"),
                    total: (.totalLength | tonumber),
                    completed: (.completedLength | tonumber),
                    progress: (if .totalLength | tonumber > 0 then ((.completedLength | tonumber) / (.totalLength | tonumber) * 100) else 0 end),
                    speed: (.downloadSpeed // "0"),
                    speedBytes: (.downloadSpeed // "0"),
                    status: (if .status == "active" then "active" elif .status == "waiting" then "waiting" else "complete" end),
                    peers: (.numSeeders // 0)
                })
            ' 2>/dev/null)
        else
            # Fallback without jq - simplified
            TASKS='[]'
        fi
        
        echo "{\"tasks\":${TASKS:-[]}}"
        ;;
    
    add)
        # Read JSON from stdin
        read -r INPUT
        URL=$(echo "$INPUT" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        
        if [ -z "$URL" ]; then
            echo '{"success": false, "error": "Invalid URL"}'
            exit 0
        fi
        
        RESULT=$(rpc_call "addUri" ",[\"${URL}\"]")
        echo "{\"success\": true, \"result\": ${RESULT}}"
        ;;
    
    pause)
        GID="$1"
        rpc_call "pause" ",\"${GID}\""
        echo '{"success": true}'
        ;;
    
    unpause)
        GID="$1"
        rpc_call "unpause" ",\"${GID}\""
        echo '{"success": true}'
        ;;
    
    remove)
        GID="$1"
        rpc_call "remove" ",\"${GID}\""
        echo '{"success": true}'
        ;;
    
    pause-all)
        rpc_call "pauseAll" ""
        echo '{"success": true}'
        ;;
    
    unpause-all)
        rpc_call "unpauseAll" ""
        echo '{"success": true}'
        ;;
    
    remove-complete)
        # Remove all stopped downloads
        rpc_call "purgeDownloadResult" ""
        echo '{"success": true}'
        ;;
    
    config)
        read -r INPUT
        
        RPC_PORT=$(echo "$INPUT" | sed -n 's/.*"rpc_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        DOWNLOAD_DIR=$(echo "$INPUT" | sed -n 's/.*"download_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        MAX_CONN=$(echo "$INPUT" | sed -n 's/.*"max_connections"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        RPC_SECRET=$(echo "$INPUT" | sed -n 's/.*"rpc_secret"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        MAX_TASKS=$(echo "$INPUT" | sed -n 's/.*"max_tasks"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        FILE_ALLOC=$(echo "$INPUT" | sed -n 's/.*"file_alloc"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        EXTRA_ARGS=$(echo "$INPUT" | sed -n 's/.*"extra_args"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        
        # Update config file
        cat > "$ARIA2_CONFIG" << EOF
# Aria2 Configuration - Managed by ClawUI
dir=${DOWNLOAD_DIR:-/var/lib/aria2}
rpc-listen-port=${RPC_PORT:-6800}
max-connection-per-server=${MAX_CONN:-16}
rpc-secret=${RPC_SECRET:-}
enable-rpc=true
rpc-allow-origin-all=true
continue=true
save-session=/var/lib/aria2/aria2.session
input-file=/var/lib/aria2/aria2.session
max-concurrent-downloads=${MAX_TASKS:-5}
file-allocation=${FILE_ALLOC:-none}
${EXTRA_ARGS}
EOF
        
        echo '{"success": true}'
        ;;
    
    log)
        if [ -f "$ARIA2_LOG" ]; then
            LOG=$(tail -100 "$ARIA2_LOG" 2>/dev/null)
        else
            LOG="No log file found"
        fi
        echo "{\"log\": \"${LOG:-No log available}\"}"
        ;;
    
    clear-log)
        : > "$ARIA2_LOG" 2>/dev/null
        echo '{"success": true}'
        ;;
    
    *)
        echo '{"error": "Unknown action"}'
        ;;
esac
