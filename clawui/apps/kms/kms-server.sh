#!/bin/sh
# Simple KMS Server implementation
# Based on py-kms and node-kms projects

PORT=${PORT:-1688}
LOG_FILE="/var/log/kms-server.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "KMS Server starting on port $PORT"

# Simple KMS response (emulates KMS server)
# This is a minimal implementation for educational purposes
handle_kms() {
    local client="$1"
    log "KMS request from $client"
    
    # Send KMS response (simplified)
    # Real KMS implementation would be more complex
    echo -e "\x00\x00\x00\x00"
}

# Main server loop using netcat
if command -v nc >/dev/null 2>&1; then
    log "Starting KMS server with netcat"
    while true; do
        nc -l -p "$PORT" -c 'echo -e "\x00\x00\x00\x00"' 2>/dev/null || \
        nc -l "$PORT" 2>/dev/null || \
        sleep 1
    done
elif command -v socat >/dev/null 2>&1; then
    log "Starting KMS server with socat"
    socat TCP-LISTEN:$PORT,reuseaddr,fork EXEC:"/bin/echo -e '\\x00\\x00\\x00\\x00'" 2>/dev/null
else
    log "ERROR: Neither nc nor socat found. Please install one of them."
    exit 1
fi
