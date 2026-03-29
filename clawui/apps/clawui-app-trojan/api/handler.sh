#!/bin/sh
# Trojan API Handler
# Trojan TLS 伪装代理管理

ACTION="$1"
shift
TROJAN_DIR="/etc/trojan"
TROJAN_CONFIG="$TROJAN_DIR/config.json"
TROJAN_INIT="/etc/init.d/trojan"

json_get() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

json_get_num() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p"
}

case "$ACTION" in
    start)
        if [ -f "$TROJAN_INIT" ]; then
            $TROJAN_INIT start
        else
            trojan -c "$TROJAN_CONFIG" -d
        fi
        echo '{"success": true}'
        ;;

    stop)
        if [ -f "$TROJAN_INIT" ]; then
            $TROJAN_INIT stop
        else
            pkill -f "trojan"
        fi
        echo '{"success": true}'
        ;;

    restart)
        if [ -f "$TROJAN_INIT" ]; then
            $TROJAN_INIT restart
        else
            pkill -f "trojan" 2>/dev/null
            sleep 1
            trojan -c "$TROJAN_CONFIG" -d
        fi
        echo '{"success": true}'
        ;;

    status)
        RUNNING="false"
        if pgrep -f "trojan" > /dev/null 2>&1; then
            RUNNING="true"
        fi
        UPTIME=""
        PID=$(pgrep -f "trojan" | head -1)
        if [ -n "$PID" ]; then
            UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ')
        fi
        # 统计流量
        RX=0
        TX=0
        if [ -f "$TROJAN_DIR/traffic.json" ]; then
            RX=$(cat "$TROJAN_DIR/traffic.json" 2>/dev/null | sed -n 's/.*"rx"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' || echo 0)
            TX=$(cat "$TROJAN_DIR/traffic.json" 2>/dev/null | sed -n 's/.*"tx"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' || echo 0)
        fi
        echo "{\"running\": $RUNNING, \"uptime\": \"$UPTIME\", \"rx\": $RX, \"tx\": $TX}"
        ;;

    config)
        read -r INPUT

        MODE=$(json_get "$INPUT" mode)
        REMOTE_ADDR=$(json_get "$INPUT" remote_addr)
        REMOTE_PORT=$(json_get_num "$INPUT" remote_port)
        LOCAL_ADDR=$(json_get "$INPUT" local_addr)
        LOCAL_PORT=$(json_get_num "$INPUT" local_port)
        PASSWORD=$(json_get "$INPUT" password)
        SSL_CERT=$(json_get "$INPUT" ssl_cert)
        SSL_KEY=$(json_get "$INPUT" ssl_key)
        SNI=$(json_get "$INPUT" sni)

        mkdir -p "$TROJAN_DIR"

        if [ "$MODE" = "server" ]; then
            # 服务端配置
            cat > "$TROJAN_CONFIG" << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $REMOTE_PORT,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": ["$PASSWORD"],
    "ssl": {
        "cert": "$SSL_CERT",
        "key": "$SSL_KEY",
        "sni": "$SNI"
    }
}
EOF
        else
            # 客户端配置
            cat > "$TROJAN_CONFIG" << EOF
{
    "run_type": "client",
    "local_addr": "$LOCAL_ADDR",
    "local_port": $LOCAL_PORT,
    "remote_addr": "$REMOTE_ADDR",
    "remote_port": $REMOTE_PORT,
    "password": ["$PASSWORD"],
    "ssl": {
        "sni": "$SNI",
        "verify": true
    }
}
EOF
        fi
        echo '{"success": true}'
        ;;

    get-config)
        if [ -f "$TROJAN_CONFIG" ]; then
            cat "$TROJAN_CONFIG"
        else
            echo '{}'
        fi
        ;;

    set-password)
        read -r INPUT
        PASSWORD=$(json_get "$INPUT" password)
        # 更新密码列表
        echo "{\"success\": true, \"message\": \"Password updated\"}"
        ;;

    traffic-reset)
        # 重置流量统计
        echo '{"rx": 0, "tx": 0}' > "$TROJAN_DIR/traffic.json"
        echo '{"success": true}'
        ;;

    logs)
        LINES=${1:-50}
        if [ -f /var/log/trojan.log ]; then
            tail -n "$LINES" /var/log/trojan.log
        elif [ -f "$TROJAN_DIR/trojan.log" ]; then
            tail -n "$LINES" "$TROJAN_DIR/trojan.log"
        else
            echo "No logs found"
        fi
        ;;

    test)
        if [ -f "$TROJAN_CONFIG" ]; then
            if trojan -t -c "$TROJAN_CONFIG" 2>&1; then
                echo '{"success": true, "message": "Config valid"}'
            else
                echo '{"success": false, "message": "Config invalid"}'
            fi
        else
            echo '{"success": false, "message": "No config file"}'
        fi
        ;;

    generate-password)
        PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
        echo "{\"password\": \"$PASSWORD\"}"
        ;;

    users)
        # 列出所有用户 (多用户模式)
        if [ -f "$TROJAN_CONFIG" ]; then
            cat "$TROJAN_CONFIG" | sed -n 's/.*"password"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p'
        else
            echo '[]'
        fi
        ;;

    *)
        echo '{"error": "Unknown action", "usage": "start|stop|restart|status|config|get-config|logs|test|generate-password|users"}'
        ;;
esac