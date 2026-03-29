#!/bin/sh
# Clash API Handler
# Clash 多节点规则代理管理

ACTION="$1"
shift
CLASH_DIR="/etc/clash"
CLASH_CONFIG="$CLASH_DIR/config.yaml"
CLASH_INIT="/etc/init.d/clash"

case "$ACTION" in
    start)
        if [ -f "$CLASH_INIT" ]; then
            $CLASH_INIT start
        else
            clash -d "$CLASH_DIR" -f "$CLASH_CONFIG" &
        fi
        echo '{"success": true}'
        ;;

    stop)
        if [ -f "$CLASH_INIT" ]; then
            $CLASH_INIT stop
        else
            pkill -f "clash"
        fi
        echo '{"success": true}'
        ;;

    restart)
        if [ -f "$CLASH_INIT" ]; then
            $CLASH_INIT restart
        else
            pkill -f "clash" 2>/dev/null
            sleep 1
            clash -d "$CLASH_DIR" -f "$CLASH_CONFIG" &
        fi
        echo '{"success": true}'
        ;;

    status)
        RUNNING="false"
        if pgrep -f "clash" > /dev/null 2>&1; then
            RUNNING="true"
        fi
        UPTIME=""
        PID=$(pgrep -f "clash" | head -1)
        if [ -n "$PID" ]; then
            UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ')
        fi
        # 获取代理模式
        MODE="unknown"
        if [ -f "$CLASH_DIR/running.yaml" ]; then
            MODE=$(grep -m1 "^mode:" "$CLASH_DIR/running.yaml" 2>/dev/null | sed 's/mode: *//' || echo "rule")
        fi
        echo "{\"running\": $RUNNING, \"uptime\": \"$UPTIME\", \"mode\": \"$MODE\"}"
        ;;

    config)
        read -r INPUT
        # 直接写入 YAML 配置 (前端已生成完整配置)
        mkdir -p "$CLASH_DIR"
        echo "$INPUT" > "$CLASH_CONFIG"
        echo '{"success": true}'
        ;;

    get-config)
        if [ -f "$CLASH_CONFIG" ]; then
            cat "$CLASH_CONFIG"
        else
            echo "# Clash 配置文件\n# 请添加节点配置"
        fi
        ;;

    proxy-mode)
        # 切换代理模式: rule/global/direct
        MODE="$1"
        if [ -z "$MODE" ]; then
            read -r INPUT
            MODE=$(echo "$INPUT" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        fi
        # 通过 API 切换模式
        if command -v curl > /dev/null 2>&1; then
            curl -s -X PATCH "http://127.0.0.1:9090/configs" -d "{\"mode\": \"$MODE\"}" 2>/dev/null
        fi
        echo "{\"success\": true, \"mode\": \"$MODE\"}"
        ;;

    proxy-select)
        # 选择代理节点
        read -r INPUT
        PROXY=$(echo "$INPUT" | sed -n 's/.*"proxy"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        GROUP=$(echo "$INPUT" | sed -n 's/.*"group"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        GROUP=${GROUP:-"PROXY"}
        if command -v curl > /dev/null 2>&1; then
            curl -s -X PUT "http://127.0.0.1:9090/proxies/$GROUP" -d "{\"name\": \"$PROXY\"}" 2>/dev/null
        fi
        echo "{\"success\": true}"
        ;;

    proxies)
        # 获取所有代理节点
        if command -v curl > /dev/null 2>&1; then
            curl -s "http://127.0.0.1:9090/proxies" 2>/dev/null
        else
            echo '{}'
        fi
        ;;

    delay)
        # 测速
        PROXY="$1"
        URL="http://www.gstatic.com/generate_204"
        if command -v curl > /dev/null 2>&1; then
            curl -s "http://127.0.0.1:9090/proxies/$PROXY/delay?timeout=5000&url=$URL" 2>/dev/null
        else
            echo '{"error": "curl not found"}'
        fi
        ;;

    delay-all)
        # 批量测速
        URL="http://www.gstatic.com/generate_204"
        if command -v curl > /dev/null 2>&1; then
            curl -s "http://127.0.0.1:9090/proxies?delay=true&timeout=5000&url=$URL" 2>/dev/null
        else
            echo '{}'
        fi
        ;;

    rules)
        # 获取规则列表
        if command -v curl > /dev/null 2>&1; then
            curl -s "http://127.0.0.1:9090/rules" 2>/dev/null
        else
            echo '[]'
        fi
        ;;

    connections)
        # 获取连接列表
        if command -v curl > /dev/null 2>&1; then
            curl -s "http://127.0.0.1:9090/connections" 2>/dev/null
        else
            echo '{"connections": []}'
        fi
        ;;

    close-connection)
        # 关闭连接
        CONN_ID="$1"
        if command -v curl > /dev/null 2>&1; then
            curl -s -X DELETE "http://127.0.0.1:9090/connections/$CONN_ID" 2>/dev/null
        fi
        echo '{"success": true}'
        ;;

    close-all-connections)
        # 关闭所有连接
        if command -v curl > /dev/null 2>&1; then
            curl -s -X DELETE "http://127.0.0.1:9090/connections" 2>/dev/null
        fi
        echo '{"success": true}'
        ;;

    logs)
        LINES=${1:-50}
        if [ -f /var/log/clash.log ]; then
            tail -n "$LINES" /var/log/clash.log
        elif [ -f "$CLASH_DIR/clash.log" ]; then
            tail -n "$LINES" "$CLASH_DIR/clash.log"
        else
            echo "No logs found"
        fi
        ;;

    traffic)
        # 实时流量
        if command -v curl > /dev/null 2>&1; then
            curl -s "http://127.0.0.1:9090/traffic" 2>/dev/null --max-time 1 || echo '{}'
        else
            echo '{}'
        fi
        ;;

    reload)
        # 重载配置
        if command -v curl > /dev/null 2>&1; then
            curl -s -X PUT "http://127.0.0.1:9090/configs" -d "{\"path\": \"$CLASH_CONFIG\"}" 2>/dev/null
        fi
        echo '{"success": true}'
        ;;

    subscription)
        # 订阅更新
        read -r INPUT
        URL=$(echo "$INPUT" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        if [ -n "$URL" ] && command -v curl > /dev/null 2>&1; then
            mkdir -p "$CLASH_DIR"
            curl -s -o "$CLASH_CONFIG" "$URL"
            echo '{"success": true, "message": "Subscription updated"}'
        else
            echo '{"success": false, "message": "Invalid URL or curl not found"}'
        fi
        ;;

    *)
        echo '{"error": "Unknown action", "usage": "start|stop|restart|status|config|get-config|proxies|delay|rules|connections|logs|reload|subscription"}'
        ;;
esac