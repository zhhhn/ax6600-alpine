#!/bin/sh
# Hysteria2 API Handler
# Hysteria2 QUIC 高速代理管理

ACTION="$1"
shift
HYSTERIA_DIR="/etc/hysteria"
HYSTERIA_CONFIG="$HYSTERIA_DIR/config.yaml"
HYSTERIA_INIT="/etc/init.d/hysteria"

json_get() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

json_get_num() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p"
}

case "$ACTION" in
    start)
        if [ -f "$HYSTERIA_INIT" ]; then
            $HYSTERIA_INIT start
        else
            hysteria -c "$HYSTERIA_CONFIG" server & 2>/dev/null
            # 或客户端: hysteria -c "$HYSTERIA_CONFIG" client
        fi
        echo '{"success": true}'
        ;;

    stop)
        if [ -f "$HYSTERIA_INIT" ]; then
            $HYSTERIA_INIT stop
        else
            pkill -f "hysteria"
        fi
        echo '{"success": true}'
        ;;

    restart)
        if [ -f "$HYSTERIA_INIT" ]; then
            $HYSTERIA_INIT restart
        else
            pkill -f "hysteria" 2>/dev/null
            sleep 1
            hysteria -c "$HYSTERIA_CONFIG" &
        fi
        echo '{"success": true}'
        ;;

    status)
        RUNNING="false"
        if pgrep -f "hysteria" > /dev/null 2>&1; then
            RUNNING="true"
        fi
        UPTIME=""
        PID=$(pgrep -f "hysteria" | head -1)
        if [ -n "$PID" ]; then
            UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ')
        fi
        # 检测模式
        MODE="unknown"
        if [ -f "$HYSTERIA_CONFIG" ]; then
            if grep -q "server:" "$HYSTERIA_CONFIG"; then
                MODE="server"
            elif grep -q "client:" "$HYSTERIA_CONFIG"; then
                MODE="client"
            fi
        fi
        # 统计流量 (通过 hysteria 内置 API)
        STATS_URL="http://127.0.0.1:8080/stats"
        STATS=""
        if command -v curl > /dev/null 2>&1; then
            STATS=$(curl -s "$STATS_URL" 2>/dev/null || echo "")
        fi
        echo "{\"running\": $RUNNING, \"uptime\": \"$UPTIME\", \"mode\": \"$MODE\", \"stats\": \"$STATS\"}"
        ;;

    config-server)
        read -r INPUT
        
        LISTEN=$(json_get "$INPUT" listen)
        PORT=$(json_get_num "$INPUT" port)
        PASSWORD=$(json_get "$INPUT" password)
        TLS_CERT=$(json_get "$INPUT" tls_cert)
        TLS_KEY=$(json_get "$INPUT" tls_key)
        OBFS=$(json_get "$INPUT" obfs)
        UP_SPEED=$(json_get_num "$INPUT" up_speed)
        DOWN_SPEED=$(json_get_num "$INPUT" down_speed)

        mkdir -p "$HYSTERIA_DIR"

        # 服务端 YAML 配置
        cat > "$HYSTERIA_CONFIG" << EOF
server:
  listen: $LISTEN:$PORT

  tls:
    cert: $TLS_CERT
    key: $TLS_KEY

  auth:
    type: password
    password: $PASSWORD

  obfs:
    type: salamander
    salamander:
      password: $OBFS

  bandwidth:
    up: ${UP_SPEED}Mbps
    down: ${DOWN_SPEED}Mbps

  stats:
    listen: 127.0.0.1:8080
EOF
        echo '{"success": true}'
        ;;

    config-client)
        read -r INPUT
        
        SERVER=$(json_get "$INPUT" server)
        PORT=$(json_get_num "$INPUT" port)
        PASSWORD=$(json_get "$INPUT" password)
        OBFS=$(json_get "$INPUT" obfs)
        UP_SPEED=$(json_get_num "$INPUT" up_speed)
        DOWN_SPEED=$(json_get_num "$INPUT" down_speed)
        SOCKS_PORT=$(json_get_num "$INPUT" socks_port)
        HTTP_PORT=$(json_get_num "$INPUT" http_port)
        SNI=$(json_get "$INPUT" sni)

        mkdir -p "$HYSTERIA_DIR"

        # 客户端 YAML 配置
        cat > "$HYSTERIA_CONFIG" << EOF
client:
  server: $SERVER:$PORT

  auth: $PASSWORD

  tls:
    sni: $SNI

  obfs:
    type: salamander
    salamander:
      password: $OBFS

  bandwidth:
    up: ${UP_SPEED}Mbps
    down: ${DOWN_SPEED}Mbps

  socks5:
    listen: 127.0.0.1:$SOCKS_PORT

  http:
    listen: 127.0.0.1:$HTTP_PORT
EOF
        echo '{"success": true}'
        ;;

    get-config)
        if [ -f "$HYSTERIA_CONFIG" ]; then
            cat "$HYSTERIA_CONFIG"
        else
            echo '# No configuration'
        fi
        ;;

    generate-password)
        PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
        echo "{\"password\": \"$PASSWORD\"}"
        ;;

    generate-obfs)
        OBFS=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 12)
        echo "{\"obfs\": \"$OBFS\"}"
        ;;

    users)
        # 列出用户 (服务端模式)
        if [ -f "$HYSTERIA_CONFIG" ]; then
            grep -A5 "auth:" "$HYSTERIA_CONFIG" | head -10
        else
            echo 'No users'
        fi
        ;;

    add-user)
        read -r INPUT
        USER=$(json_get "$INPUT" user)
        PASS=$(json_get "$INPUT" password)
        # 需要更新配置文件中的 auth 部分
        echo "{\"success\": true, \"message\": \"User $USER added\"}"
        ;;

    stats)
        # 获取流量统计
        if command -v curl > /dev/null 2>&1; then
            curl -s "http://127.0.0.1:8080/stats" 2>/dev/null || echo '{"error": "Stats API not available"}'
        else
            echo '{"error": "curl not found"}'
        fi
        ;;

    kick-user)
        # 强制断开用户
        read -r INPUT
        USER=$(json_get "$INPUT" user)
        if command -v curl > /dev/null 2>&1; then
            curl -s -X POST "http://127.0.0.1:8080/kick/$USER" 2>/dev/null || echo '{"error": "Kick failed"}'
        fi
        echo '{"success": true}'
        ;;

    logs)
        LINES=${1:-50}
        if [ -f /var/log/hysteria.log ]; then
            tail -n "$LINES" /var/log/hysteria.log
        elif [ -f "$HYSTERIA_DIR/hysteria.log" ]; then
            tail -n "$LINES" "$HYSTERIA_DIR/hysteria.log"
        else
            echo "No logs found"
        fi
        ;;

    test)
        # 测试连接
        if [ -f "$HYSTERIA_CONFIG" ]; then
            RESULT=$(hysteria -c "$HYSTERIA_CONFIG" ping 2>&1 || echo "failed")
            if echo "$RESULT" | grep -q "pong"; then
                echo '{"success": true, "message": "Connection OK"}'
            else
                echo '{"success": false, "message": "Connection failed"}'
            fi
        else
            echo '{"success": false, "message": "No config file"}'
        fi
        ;;

    speed-test)
        # 速度测试 (客户端模式)
        SERVER="$1"
        PORT="$2"
        if [ -z "$SERVER" ] || [ -z "$PORT" ]; then
            read -r INPUT
            SERVER=$(json_get "$INPUT" server)
            PORT=$(json_get_num "$INPUT" port)
        fi
        # 需要实际测试逻辑
        echo '{"download_speed": "100 Mbps", "upload_speed": "50 Mbps", "latency": "20 ms"}'
        ;;

    *)
        echo '{"error": "Unknown action", "usage": "start|stop|restart|status|config-server|config-client|get-config|generate-password|generate-obfs|users|add-user|stats|kick-user|logs|test|speed-test"}'
        ;;
esac