#!/bin/sh
# HomeProxy API Handler
# 透明代理网关管理 - 支持多节点分流规则

ACTION="$1"
shift
HP_DIR="/etc/homeproxy"
HP_CONFIG="$HP_DIR/config.json"
HP_RULES="$HP_DIR/rules.json"
HP_NODES="$HP_DIR/nodes.json"
HP_INIT="/etc/init.d/homeproxy"

json_get() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

json_get_num() {
    echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p"
}

json_get_bool() {
    val=$(echo "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p")
    [ "$val" = "true" ] && return 0 || return 1
}

# 创建 ipset 和 iptables 规则
setup_firewall() {
    # 创建 ipset
    ipset create homeproxy_bypass hash:ip 2>/dev/null || ipset flush homeproxy_bypass
    ipset create homeproxy_proxy hash:ip 2>/dev/null || ipset flush homeproxy_proxy
    ipset create homeproxy_direct hash:ip 2>/dev/null || ipset flush homeproxy_direct
    ipset create homeproxy_block hash:ip 2>/dev/null || ipset flush homeproxy_block

    # iptables 规则 (透明代理)
    # 清理旧规则
    iptables -t nat -D PREROUTING -j homeproxy_pre 2>/dev/null
    iptables -t nat -F homeproxy_pre 2>/dev/null
    iptables -t nat -X homeproxy_pre 2>/dev/null

    iptables -t mangle -D PREROUTING -j homeproxy_mark 2>/dev/null
    iptables -t mangle -F homeproxy_mark 2>/dev/null
    iptables -t mangle -X homeproxy_mark 2>/dev/null

    # 创建新链
    iptables -t nat -N homeproxy_pre 2>/dev/null
    iptables -t mangle -N homeproxy_mark 2>/dev/null

    # 排除内网地址
    iptables -t nat -A homeproxy_pre -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A homeproxy_pre -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A homeproxy_pre -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A homeproxy_pre -d 127.0.0.0/8 -j RETURN

    # 排除本地 DNS
    iptables -t nat -A homeproxy_pre -p udp --dport 53 -j RETURN

    # 直连地址 (ipset)
    iptables -t nat -A homeproxy_pre -m set --match-set homeproxy_direct dst -j RETURN

    # 绕过地址
    iptables -t nat -A homeproxy_pre -m set --match-set homeproxy_bypass dst -j RETURN

    # 需要代理的地址
    iptables -t nat -A homeproxy_pre -m set --match-set homeproxy_proxy dst -j REDIRECT --to-ports $PROXY_PORT

    # 阻止地址
    iptables -t nat -A homeproxy_pre -m set --match-set homeproxy_block dst -j DROP

    # 插入 PREROUTING 链
    iptables -t nat -A PREROUTING -j homeproxy_pre

    # 标记规则 (用于策略路由)
    iptables -t mangle -A homeproxy_mark -m set --match-set homeproxy_proxy dst -j MARK --set-mark 1
    iptables -t mangle -A PREROUTING -j homeproxy_mark

    return 0
}

cleanup_firewall() {
    iptables -t nat -D PREROUTING -j homeproxy_pre 2>/dev/null
    iptables -t nat -F homeproxy_pre 2>/dev/null
    iptables -t nat -X homeproxy_pre 2>/dev/null
    iptables -t mangle -D PREROUTING -j homeproxy_mark 2>/dev/null
    iptables -t mangle -F homeproxy_mark 2>/dev/null
    iptables -t mangle -X homeproxy_mark 2>/dev/null
    ipset destroy homeproxy_bypass 2>/dev/null
    ipset destroy homeproxy_proxy 2>/dev/null
    ipset destroy homeproxy_direct 2>/dev/null
    ipset destroy homeproxy_block 2>/dev/null
    return 0
}

case "$ACTION" in
    start)
        mkdir -p "$HP_DIR"
        
        # 读取配置获取代理端口
        PROXY_PORT="1080"
        if [ -f "$HP_CONFIG" ]; then
            PROXY_PORT=$(json_get_num "$(cat $HP_CONFIG)" proxy_port)
        fi
        PROXY_PORT=${PROXY_PORT:-1080}

        # 设置防火墙规则
        setup_firewall

        # 加载节点规则到 ipset
        if [ -f "$HP_RULES" ]; then
            # 加载直连规则
            cat "$HP_RULES" | while read line; do
                rule=$(echo "$line" | sed 's/.*"ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                type=$(echo "$line" | sed 's/.*"type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                if [ "$type" = "direct" ] && [ -n "$rule" ]; then
                    ipset add homeproxy_direct "$rule" 2>/dev/null
                elif [ "$type" = "proxy" ] && [ -n "$rule" ]; then
                    ipset add homeproxy_proxy "$rule" 2>/dev/null
                elif [ "$type" = "block" ] && [ -n "$rule" ]; then
                    ipset add homeproxy_block "$rule" 2>/dev/null
                fi
            done
        fi

        # 启动代理客户端 (需要配合其他代理)
        # 这里只设置透明代理规则，代理本身由其他应用提供

        # 记录状态
        echo '{"running": true}' > "$HP_DIR/status.json"

        echo '{"success": true, "message": "Transparent proxy enabled"}'
        ;;

    stop)
        cleanup_firewall
        echo '{"running": false}' > "$HP_DIR/status.json"
        echo '{"success": true, "message": "Transparent proxy disabled"}'
        ;;

    restart)
        cleanup_firewall
        sleep 1
        mkdir -p "$HP_DIR"
        PROXY_PORT="1080"
        if [ -f "$HP_CONFIG" ]; then
            PROXY_PORT=$(json_get_num "$(cat $HP_CONFIG)" proxy_port)
        fi
        setup_firewall
        echo '{"success": true}'
        ;;

    status)
        RUNNING="false"
        if iptables -t nat -L homeproxy_pre 2>/dev/null | grep -q "homeproxy"; then
            RUNNING="true"
        fi

        # 统计连接数
        CONNS=$(iptables -t nat -L homeproxy_pre -v 2>/dev/null | grep REDIRECT | awk '{print $1}' || echo 0)

        # 获取 ipset 条目数
        DIRECT_COUNT=$(ipset list homeproxy_direct 2>/dev/null | wc -l || echo 0)
        PROXY_COUNT=$(ipset list homeproxy_proxy 2>/dev/null | wc -l || echo 0)
        BLOCK_COUNT=$(ipset list homeproxy_block 2>/dev/null | wc -l || echo 0)

        # 当前节点
        CURRENT_NODE=""
        if [ -f "$HP_CONFIG" ]; then
            CURRENT_NODE=$(json_get "$(cat $HP_CONFIG)" default_node)
        fi

        echo "{\"running\": $RUNNING, \"connections\": $CONNS, \"direct_rules\": $DIRECT_COUNT, \"proxy_rules\": $PROXY_COUNT, \"block_rules\": $BLOCK_COUNT, \"current_node\": \"$CURRENT_NODE\"}"
        ;;

    config)
        read -r INPUT

        MODE=$(json_get "$INPUT" mode)
        PROXY_PORT=$(json_get_num "$INPUT" proxy_port)
        DEFAULT_NODE=$(json_get "$INPUT" default_node)
        IPV6=$(json_get_bool "$INPUT" ipv6 && echo "true" || echo "false")
        DNS_PROXY=$(json_get_bool "$INPUT" dns_proxy && echo "true" || echo "false")

        mkdir -p "$HP_DIR"

        cat > "$HP_CONFIG" << EOF
{
    "mode": "$MODE",
    "proxy_port": $PROXY_PORT,
    "default_node": "$DEFAULT_NODE",
    "ipv6": $IPV6,
    "dns_proxy": $DNS_PROXY
}
EOF
        echo '{"success": true}'
        ;;

    get-config)
        if [ -f "$HP_CONFIG" ]; then
            cat "$HP_CONFIG"
        else
            echo '{"mode": "proxy", "proxy_port": 1080, "default_node": "", "ipv6": false, "dns_proxy": true}'
        fi
        ;;

    add-node)
        read -r INPUT
        
        NAME=$(json_get "$INPUT" name)
        TYPE=$(json_get "$INPUT" type)
        SERVER=$(json_get "$INPUT" server)
        PORT=$(json_get_num "$INPUT" port)
        PASSWORD=$(json_get "$INPUT" password)
        UUID=$(json_get "$INPUT" uuid)

        mkdir -p "$HP_DIR"

        # 加载现有节点
        if [ -f "$HP_NODES" ]; then
            NODES=$(cat "$HP_NODES")
        else
            NODES='{"nodes": []}'
        fi

        # 添加节点 (简化处理)
        echo "$NODES" | sed "s/\"nodes\": \[/\"nodes\": [{\"name\": \"$NAME\", \"type\": \"$TYPE\", \"server\": \"$SERVER\", \"port\": $PORT},/" > "$HP_NODES"
        echo '{"success": true}'
        ;;

    nodes)
        if [ -f "$HP_NODES" ]; then
            cat "$HP_NODES"
        else
            echo '{"nodes": []}'
        fi
        ;;

    set-default-node)
        read -r INPUT
        NODE=$(json_get "$INPUT" node)
        # 更新配置
        if [ -f "$HP_CONFIG" ]; then
            sed -i "s/\"default_node\": \"[^\"]*\"/\"default_node\": \"$NODE\"/" "$HP_CONFIG"
        fi
        echo '{"success": true}'
        ;;

    add-rule)
        read -r INPUT

        IP=$(json_get "$INPUT" ip)
        DOMAIN=$(json_get "$INPUT" domain)
        TYPE=$(json_get "$INPUT" type)  # direct/proxy/block

        if [ -z "$TYPE" ]; then
            echo '{"success": false, "message": "Missing rule type"}'
            exit 0
        fi

        # 添加到 ipset
        if [ -n "$IP" ]; then
            case "$TYPE" in
                direct) ipset add homeproxy_direct "$IP" 2>/dev/null ;;
                proxy) ipset add homeproxy_proxy "$IP" 2>/dev/null ;;
                block) ipset add homeproxy_block "$IP" 2>/dev/null ;;
            esac
        fi

        # 保存规则
        mkdir -p "$HP_DIR"
        echo "{\"ip\": \"$IP\", \"domain\": \"$DOMAIN\", \"type\": \"$TYPE\"}" >> "$HP_RULES"

        echo '{"success": true}'
        ;;

    rules)
        if [ -f "$HP_RULES" ]; then
            cat "$HP_RULES"
        else
            echo '[]'
        fi
        ;;

    del-rule)
        read -r INPUT
        IP=$(json_get "$INPUT" ip)
        TYPE=$(json_get "$INPUT" type)

        # 从 ipset 移除
        if [ -n "$IP" ]; then
            case "$TYPE" in
                direct) ipset del homeproxy_direct "$IP" 2>/dev/null ;;
                proxy) ipset del homeproxy_proxy "$IP" 2>/dev/null ;;
                block) ipset del homeproxy_block "$IP" 2>/dev/null ;;
            esac
        fi

        echo '{"success": true}'
        ;;

    import-rules)
        # 从订阅导入规则
        URL="$1"
        if [ -z "$URL" ]; then
            read -r INPUT
            URL=$(json_get "$INPUT" url)
        fi

        mkdir -p "$HP_DIR"

        if command -v curl > /dev/null 2>&1 && [ -n "$URL" ]; then
            curl -s "$URL" -o "$HP_DIR/imported_rules.txt"
            # 解析并添加到 ipset
            while read line; do
                if [ -n "$line" ]; then
                    ipset add homeproxy_proxy "$line" 2>/dev/null
                fi
            done < "$HP_DIR/imported_rules.txt"
            echo '{"success": true}'
        else
            echo '{"success": false, "message": "curl not found or URL empty"}'
        fi
        ;;

    clear-rules)
        ipset flush homeproxy_bypass 2>/dev/null
        ipset flush homeproxy_proxy 2>/dev/null
        ipset flush homeproxy_direct 2>/dev/null
        ipset flush homeproxy_block 2>/dev/null
        rm -f "$HP_RULES"
        echo '{"success": true}'
        ;;

    set-mode)
        # 全局模式切换: proxy/direct/off
        MODE="$1"
        if [ -z "$MODE" ]; then
            read -r INPUT
            MODE=$(json_get "$INPUT" mode)
        fi

        case "$MODE" in
            proxy)
                # 恢复代理规则
                iptables -t nat -A homeproxy_pre -m set --match-set homeproxy_proxy dst -j REDIRECT --to-ports $PROXY_PORT
                ;;
            direct)
                # 清除 REDIRECT 规则，全部直连
                iptables -t nat -F homeproxy_pre
                iptables -t nat -A homeproxy_pre -j RETURN
                ;;
            off)
                cleanup_firewall
                ;;
        esac

        echo "{\"success\": true, \"mode\": \"$MODE\"}"
        ;;

    dns-config)
        read -r INPUT

        DNS_PROXY=$(json_get_bool "$INPUT" enabled && echo "true" || echo "false")
        DNS_SERVER=$(json_get "$INPUT" server)

        # DNS 透明代理设置
        if [ "$DNS_PROXY" = "true" ]; then
            # 重定向 DNS 到代理 DNS 服务器
            iptables -t nat -A homeproxy_pre -p udp --dport 53 -j DNAT --to-destination "$DNS_SERVER":53 2>/dev/null
            iptables -t nat -A homeproxy_pre -p tcp --dport 53 -j DNAT --to-destination "$DNS_SERVER":53 2>/dev/null
        fi

        echo '{"success": true}'
        ;;

    test-ip)
        IP="$1"
        # 测试 IP 的分流状态
        if ipset test homeproxy_direct "$IP" 2>/dev/null; then
            echo '{"result": "direct"}'
        elif ipset test homeproxy_proxy "$IP" 2>/dev/null; then
            echo '{"result": "proxy"}'
        elif ipset test homeproxy_block "$IP" 2>/dev/null; then
            echo '{"result": "block"}'
        else
            # 默认行为
            if [ -f "$HP_CONFIG" ]; then
                DEFAULT=$(json_get "$(cat $HP_CONFIG)" mode)
                echo "{\"result\": \"$DEFAULT\"}"
            else
                echo '{"result": "proxy"}'
            fi
        fi
        ;;

    logs)
        LINES=${1:-50}
        if [ -f /var/log/homeproxy.log ]; then
            tail -n "$LINES" /var/log/homeproxy.log
        else
            # 使用 iptables log
            dmesg | grep "homeproxy" | tail -n "$LINES" || echo "No logs"
        fi
        ;;

    stats)
        # 流量统计 (通过 iptables)
        TX=$(iptables -t nat -L homeproxy_pre -v 2>/dev/null | grep REDIRECT | awk '{print $2}' | head -1 || echo 0)
        RX=$(iptables -t nat -L homeproxy_pre -v 2>/dev/null | grep REDIRECT | awk '{print $3}' | head -1 || echo 0)
        echo "{\"tx\": \"$TX\", \"rx\": \"$RX\"}"
        ;;

    *)
        echo '{"error": "Unknown action", "usage": "start|stop|restart|status|config|add-node|nodes|add-rule|rules|del-rule|import-rules|clear-rules|set-mode|dns-config|test-ip|logs|stats"}'
        ;;
esac