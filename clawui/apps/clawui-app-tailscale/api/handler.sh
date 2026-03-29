#!/bin/sh
# Tailscale API Handler
ACTION="$1"; shift
case "$ACTION" in
    start) tailscale up 2>/dev/null; echo '{"success": true}' ;;
    stop) tailscale down 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "tailscaled" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        STATUS=$(tailscale status --json 2>/dev/null | head -20)
        echo "{\"running\": ${RUNNING}, \"info\": $STATUS}"
        ;;
    login)
        read -r INPUT
        KEY=$(echo "$INPUT" | sed -n 's/.*"auth_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        tailscale up --authkey="$KEY" 2>/dev/null
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
