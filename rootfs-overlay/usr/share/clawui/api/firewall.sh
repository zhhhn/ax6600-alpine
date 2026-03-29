#!/bin/sh
# ClawUI Firewall API
# nftables/iptables firewall management

# Get firewall status
get_firewall_status() {
    local enabled="false"
    local rules_count=0
    
    if rc-service firewall status 2>/dev/null | grep -q started; then
        enabled="true"
    fi
    
    rules_count=$(nft list ruleset 2>/dev/null | grep -c "add rule" || echo 0)
    
    cat << EOF
{
    "enabled": $enabled,
    "rules_count": $rules_count,
    "zones": [
        {"name": "lan", "input": "ACCEPT", "output": "ACCEPT", "forward": "ACCEPT"},
        {"name": "wan", "input": "DROP", "output": "ACCEPT", "forward": "DROP"}
    ],
    "nat": {
        "enabled": true,
        "type": "masquerade"
    }
}
EOF
}

# Get port forwards
get_port_forwards() {
    echo "["
    if [ -f /etc/port-forward.rules ]; then
        while IFS=: read proto ext_port int_ip int_port; do
            [ -n "$proto" ] && echo "{\"proto\": \"$proto\", \"ext_port\": $ext_port, \"int_ip\": \"$int_ip\", \"int_port\": $int_port},"
        done < /etc/port-forward.rules
    fi | sed '$ s/,$//'
    echo "]"
}

# Add port forward
add_port_forward() {
    read -n $CONTENT_LENGTH data
    
    local proto=$(echo "$data" | grep -o '"proto":"[^"]*"' | cut -d'"' -f4)
    local ext_port=$(echo "$data" | grep -o '"ext_port":[0-9]*' | cut -d: -f2)
    local int_ip=$(echo "$data" | grep -o '"int_ip":"[^"]*"' | cut -d'"' -f4)
    local int_port=$(echo "$data" | grep -o '"int_port":[0-9]*' | cut -d: -f2)
    
    if [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ]; then
        echo "${proto:-tcp}:${ext_port}:${int_ip}:${int_port}" >> /etc/port-forward.rules
        /usr/sbin/port-forward apply
        echo '{"success": true, "message": "Port forward added"}'
    else
        echo '{"success": false, "message": "Missing parameters"}'
    fi
}

# Delete port forward
delete_port_forward() {
    local id=$(echo "$QUERY_STRING" | grep -o 'id=[^&]*' | cut -d= -f2)
    
    if [ -n "$id" ]; then
        sed -i "${id}d" /etc/port-forward.rules
        /usr/sbin/port-forward apply
        echo '{"success": true, "message": "Port forward deleted"}'
    else
        echo '{"success": false, "message": "No id specified"}'
    fi
}

# Get traffic rules (custom firewall rules)
get_traffic_rules() {
    echo "["
    nft list table inet filter 2>/dev/null | grep "add rule" | head -20 | while read line; do
        echo "{\"rule\": \"$line\"},"
    done | sed '$ s/,$//'
    echo "]"
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/firewall/forwards)
                get_port_forwards
                ;;
            /api/firewall/rules)
                get_traffic_rules
                ;;
            *)
                get_firewall_status
                ;;
        esac
        ;;
    POST)
        case "$PATH_INFO" in
            /api/firewall/forwards)
                add_port_forward
                ;;
            /api/firewall/reload)
                rc-service firewall restart
                echo '{"success": true, "message": "Firewall reloaded"}'
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        delete_port_forward
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac