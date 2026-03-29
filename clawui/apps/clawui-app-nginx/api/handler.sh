#!/bin/sh
# Nginx API Handler
ACTION="$1"; shift
NGINX_CONF="/etc/nginx/nginx.conf"
case "$ACTION" in
    start) /etc/init.d/nginx start 2>/dev/null; echo '{"success": true}' ;;
    stop) /etc/init.d/nginx stop 2>/dev/null; echo '{"success": true}' ;;
    reload) /etc/init.d/nginx reload 2>/dev/null; echo '{"success": true}' ;;
    status)
        if pgrep -f "nginx" > /dev/null 2>&1; then RUNNING="true"; else RUNNING="false"; fi
        echo "{\"running\": ${RUNNING}}"
        ;;
    add-site)
        read -r INPUT
        DOMAIN=$(echo "$INPUT" | sed -n 's/.*"domain"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        ROOT=$(echo "$INPUT" | sed -n 's/.*"root"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        PORT=$(echo "$INPUT" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        mkdir -p /etc/nginx/sites-enabled
        cat > "/etc/nginx/sites-enabled/$DOMAIN.conf" << EOF
server {
    listen $PORT;
    server_name $DOMAIN;
    root $ROOT;
    index index.html index.htm;
    location / { try_files \$uri \$uri/ =404; }
}
EOF
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
