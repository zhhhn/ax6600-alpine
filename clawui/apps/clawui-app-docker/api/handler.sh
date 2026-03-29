#!/bin/sh
# Docker API Handler
ACTION="$1"; shift
case "$ACTION" in
    status)
        if pgrep -f "dockerd" > /dev/null 2>&1; then
            echo '{"dockerRunning": true}'
        else
            echo '{"dockerRunning": false}'
        fi
        ;;
    containers)
        docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.ID}}' 2>/dev/null | while IFS='|' read name image status id; do
            running=$(echo "$status" | grep -q "Up" && echo "true" || echo "false")
            echo "{\"name\":\"$name\",\"image\":\"$image\",\"status\":\"$status\",\"id\":\"$id\",\"running\":$running}"
        done | jq -s '.' 2>/dev/null || echo '[]'
        ;;
    run)
        read -r INPUT
        IMAGE=$(echo "$INPUT" | sed -n 's/.*"image"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        NAME=$(echo "$INPUT" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        PORTS=$(echo "$INPUT" | sed -n 's/.*"ports"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        docker run -d ${PORTS:+-p $PORTS} --name "$NAME" "$IMAGE" 2>/dev/null
        echo '{"success": true}'
        ;;
    start) read -r INPUT; ID=$(echo "$INPUT" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'); docker start "$ID" 2>/dev/null; echo '{"success": true}' ;;
    stop) read -r INPUT; ID=$(echo "$INPUT" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'); docker stop "$ID" 2>/dev/null; echo '{"success": true}' ;;
    remove) read -r INPUT; ID=$(echo "$INPUT" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'); docker rm -f "$ID" 2>/dev/null; echo '{"success": true}' ;;
    *) echo '{"error": "Unknown"}' ;;
esac
