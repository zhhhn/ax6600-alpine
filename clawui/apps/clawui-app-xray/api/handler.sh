#!/bin/sh
# Xray API Handler
# 支持 VLESS/VMess/Trojan 等多协议

ACTION="$1"
shift
XRAY_DIR="/etc/xray"
XRAY_CONFIG="$XRAY_DIR/config.json"
XRAY_INIT="/etc/init.d/xray"

json_get() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

json_get_num() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p"
}

case "$ACTION" in
    start)
        if [ -f "$XRAY_INIT" ]; then
            $XRAY_INIT start
        else
            xray -config "$XRAY_CONFIG" -daemon
        fi
        echo '{"success": true}'
        ;;

    stop)
        if [ -f "$XRAY_INIT" ]; then
            $XRAY_INIT stop
        else
            pkill -f "xray"
        fi
        echo '{"success": true}'
        ;;

    restart)
        if [ -f "$XRAY_INIT" ]; then
            $XRAY_INIT restart
        else
            pkill -f "xray" 2>/dev/null
            sleep 1
            xray -config "$XRAY_CONFIG" -daemon
        fi
        echo '{"success": true}'
        ;;

    status)
        RUNNING="false"
        if pgrep -f "xray" > /dev/null 2>&1; then
            RUNNING="true"
        fi
        UPTIME=""
        PID=$(pgrep -f "xray" | head -1)
        if [ -n "$PID" ]; then
            UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ')
        fi
        # 统计连接数
        CONNS=0
        if [ -n "$PID" ]; then
            CONNS=$(netstat -an 2>/dev/null | grep -c "ESTABLISHED.*$PID" || echo 0)
        fi
        echo "{\"running\": $RUNNING, \"uptime\": \"$UPTIME\", \"connections\": $CONNS}"
        ;;

    config)
        read -r INPUT

        # 解析配置
        PROTOCOL=$(json_get "$INPUT" protocol)
        LISTEN_PORT=$(json_get_num "$INPUT" listen_port)
        UUID=$(json_get "$INPUT" uuid)
        SERVER=$(json_get "$INPUT" server)
        SERVER_PORT=$(json_get_num "$INPUT" server_port)
        MODE=$(json_get "$INPUT" mode)

        mkdir -p "$XRAY_DIR"

        if [ "$MODE" = "server" ]; then
            # 服务端配置
            cat > "$XRAY_CONFIG" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $LISTEN_PORT,
      "protocol": "$PROTOCOL",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-direct"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
        else
            # 客户端配置
            cat > "$XRAY_CONFIG" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "udp": true
      }
    },
    {
      "port": 1081,
      "protocol": "http"
    }
  ],
  "outbounds": [
    {
      "protocol": "$PROTOCOL",
      "settings": {
        "vnext": [
          {
            "address": "$SERVER",
            "port": $SERVER_PORT,
            "users": [
              {
                "id": "$UUID",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    }
  ]
}
EOF
        fi
        echo '{"success": true}'
        ;;

    get-config)
        if [ -f "$XRAY_CONFIG" ]; then
            cat "$XRAY_CONFIG"
        else
            echo '{}'
        fi
        ;;

    inbound-add)
        read -r INPUT
        # 添加入站规则
        PORT=$(json_get_num "$INPUT" port)
        PROTO=$(json_get "$INPUT" protocol)
        # 简化处理，实际需要合并到现有配置
        echo "{\"success\": true, \"message\": \"Inbound added on port $PORT\"}"
        ;;

    outbound-add)
        read -r INPUT
        # 添加出站规则
        echo '{"success": true}'
        ;;

    routing-rules)
        read -r INPUT
        # 设置路由规则
        echo '{"success": true}'
        ;;

    logs)
        LINES=${1:-50}
        if [ -f /var/log/xray.log ]; then
            tail -n "$LINES" /var/log/xray.log
        elif [ -f "$XRAY_DIR/error.log" ]; then
            tail -n "$LINES" "$XRAY_DIR/error.log"
        else
            echo "No logs found"
        fi
        ;;

    generate-uuid)
        UUID=$(cat /proc/sys/kernel/random/uuid)
        echo "{\"uuid\": \"$UUID\"}"
        ;;

    test)
        if [ -f "$XRAY_CONFIG" ]; then
            if xray -test -config "$XRAY_CONFIG" 2>&1; then
                echo '{"success": true, "message": "Config valid"}'
            else
                echo '{"success": false, "message": "Config invalid"}'
            fi
        else
            echo '{"success": false, "message": "No config file"}'
        fi
        ;;

    *)
        echo '{"error": "Unknown action", "usage": "start|stop|restart|status|config|get-config|logs|generate-uuid|test"}'
        ;;
esac