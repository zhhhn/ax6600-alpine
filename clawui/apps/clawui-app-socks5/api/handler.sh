#!/bin/sh
# SOCKS5 Server API Handler
# Dante SOCKS5 代理服务端管理

ACTION="$1"
shift
SOCKS_DIR="/etc/socks"
SOCKS_CONFIG="$SOCKS_DIR/sockd.conf"
SOCKS_INIT="/etc/init.d/sockd"

json_get() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

json_get_num() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p"
}

json_get_bool() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*(true|false).*/\1/p"
}

case "$ACTION" in
    start)
        if [ -f "$SOCKS_INIT" ]; then
            $SOCKS_INIT start
        else
            sockd -f "$SOCKS_CONFIG" -D
        fi
        echo '{"success": true}'
        ;;

    stop)
        if [ -f "$SOCKS_INIT" ]; then
            $SOCKS_INIT stop
        else
            pkill -f "sockd"
        fi
        echo '{"success": true}'
        ;;

    restart)
        if [ -f "$SOCKS_INIT" ]; then
            $SOCKS_INIT restart
        else
            pkill -f "sockd" 2>/dev/null
            sleep 1
            sockd -f "$SOCKS_CONFIG" -D
        fi
        echo '{"success": true}'
        ;;

    status)
        RUNNING="false"
        if pgrep -f "sockd" > /dev/null 2>&1; then
            RUNNING="true"
        fi
        UPTIME=""
        PID=$(pgrep -f "sockd" | head -1)
        if [ -n "$PID" ]; then
            UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ')
        fi
        # 获取监听端口
        PORT="1080"
        if [ -f "$SOCKS_CONFIG" ]; then
            PORT=$(grep -m1 "port" "$SOCKS_CONFIG" 2>/dev/null | sed 's/.*port[[:space:]]*=[[:space:]]*//' || echo "1080")
        fi
        # 统计连接数
        CONNS=0
        if [ -n "$PID" ]; then
            CONNS=$(netstat -an 2>/dev/null | grep -c "ESTABLISHED.*:$PORT" || echo 0)
        fi
        echo "{\"running\": $RUNNING, \"uptime\": \"$UPTIME\", \"port\": $PORT, \"connections\": $CONNS}"
        ;;

    config)
        read -r INPUT

        PORT=$(json_get_num "$INPUT" port)
        INTERNAL=$(json_get "$INPUT" internal)
        EXTERNAL=$(json_get "$INPUT" external)
        METHOD=$(json_get "$INPUT" method)
        USER=$(json_get "$INPUT" user)
        PASS=$(json_get "$INPUT" password)
        UDP=$(json_get_bool "$INPUT" udp_support)

        mkdir -p "$SOCKS_DIR"

        # 创建 Dante 配置
        cat > "$SOCKS_CONFIG" << EOF
# SOCKS5 Server Configuration
logoutput: /var/log/sockd.log

internal: $INTERNAL port = $PORT
external: $EXTERNAL

clientmethod: none
socksmethod: $METHOD

# 访问规则
client {
    pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
    }
    block {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error
    }
}

socks {
    pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        command: bind connect udpassociate
        log: error
    }
    block {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error connect
    }
}
EOF

        # 如果需要认证，添加用户
        if [ "$METHOD" = "username" ] && [ -n "$USER" ] && [ -n "$PASS" ]; then
            # Dante 使用系统用户认证
            if id "$USER" >/dev/null 2>&1; then
                echo "User $USER already exists"
            else
                adduser -D -H "$USER" 2>/dev/null || true
                echo "$USER:$PASS" | chpasswd 2>/dev/null || true
            fi
        fi

        echo '{"success": true}'
        ;;

    get-config)
        if [ -f "$SOCKS_CONFIG" ]; then
            cat "$SOCKS_CONFIG"
        else
            echo '# No configuration'
        fi
        ;;

    users)
        # 列出允许的用户
        if [ -f "$SOCKS_CONFIG" ]; then
            grep -A2 "socksmethod:" "$SOCKS_CONFIG" | grep -v "^#" | head -5
        else
            echo 'No users configured'
        fi
        ;;

    add-user)
        read -r INPUT
        USER=$(json_get "$INPUT" user)
        PASS=$(json_get "$INPUT" password)

        if [ -z "$USER" ] || [ -z "$PASS" ]; then
            echo '{"success": false, "message": "Missing user or password"}'
            exit 0
        fi

        # 创建系统用户
        if id "$USER" >/dev/null 2>&1; then
            echo '{"success": false, "message": "User already exists"}'
        else
            adduser -D -H "$USER" 2>/dev/null || true
            echo "$USER:$PASS" | chpasswd 2>/dev/null || true
            echo '{"success": true, "message": "User added"}'
        fi
        ;;

    del-user)
        read -r INPUT
        USER=$(json_get "$INPUT" user)
        
        if id "$USER" >/dev/null 2>&1; then
            deluser "$USER" 2>/dev/null || true
            echo '{"success": true, "message": "User deleted"}'
        else
            echo '{"success": false, "message": "User not found"}'
        fi
        ;;

    set-method)
        # 设置认证方式: none/username
        METHOD="$1"
        if [ -z "$METHOD" ]; then
            read -r INPUT
            METHOD=$(json_get "$INPUT" method)
        fi
        # 更新配置中的 socksmethod
        if [ -f "$SOCKS_CONFIG" ]; then
            sed -i "s/socksmethod: .*/socksmethod: $METHOD/" "$SOCKS_CONFIG"
        fi
        echo "{\"success\": true, \"method\": \"$METHOD\"}"
        ;;

    interfaces)
        # 获取可用网络接口
        ip addr show | grep -E "^[0-9]+:" | sed 's/[0-9]+: \([^:]*\):.*/\1/' | grep -v "lo"
        ;;

    get-ip)
        # 获取接口 IP
        IFACE="$1"
        ip addr show "$IFACE" 2>/dev/null | grep "inet " | sed 's/.*inet \([^ ]*\) .*/\1/' | head -1
        ;;

    logs)
        LINES=${1:-50}
        if [ -f /var/log/sockd.log ]; then
            tail -n "$LINES" /var/log/sockd.log
        else
            echo "No logs found"
        fi
        ;;

    test)
        # 测试 SOCKS5 连接
        PORT="1080"
        if [ -f "$SOCKS_CONFIG" ]; then
            PORT=$(grep -m1 "port" "$SOCKS_CONFIG" 2>/dev/null | sed 's/.*port[[:space:]]*=[[:space:]]*//' || echo "1080")
        fi
        if command -v curl > /dev/null 2>&1; then
            RESULT=$(curl -s --socks5 127.0.0.1:$PORT --max-time 5 http://www.gstatic.com/generate_204 -w "%{http_code}" || echo "000")
            if [ "$RESULT" = "204" ]; then
                echo '{"success": true, "message": "Proxy working"}'
            else
                echo '{"success": false, "message": "Proxy not working"}'
            fi
        else
            echo '{"success": false, "message": "curl not found"}'
        fi
        ;;

    stats)
        # 获取流量统计 (需要 iptables 记录)
        PORT="1080"
        if [ -f "$SOCKS_CONFIG" ]; then
            PORT=$(grep -m1 "port" "$SOCKS_CONFIG" 2>/dev/null | sed 's/.*port[[:space:]]*=[[:space:]]*//' || echo "1080")
        fi
        RX=0
        TX=0
        if command -v iptables > /dev/null 2>&1; then
            RX=$(iptables -L -v -n 2>/dev/null | grep "socks5-in" | awk '{print $2}' || echo 0)
            TX=$(iptables -L -v -n 2>/dev/null | grep "socks5-out" | awk '{print $2}' || echo 0)
        fi
        echo "{\"rx\": \"$RX\", \"tx\": \"$TX\"}"
        ;;

    *)
        echo '{"error": "Unknown action", "usage": "start|stop|restart|status|config|get-config|users|add-user|del-user|set-method|interfaces|logs|test|stats"}'
        ;;
esac