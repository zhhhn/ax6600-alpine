#!/bin/sh
# ClawUI Static Routes App API
# Static route management with policy routing support

IP="/sbin/ip"
CONF_DIR="/etc/clawui/routes"
ROUTES_CONF="$CONF_DIR/routes.json"
POLICY_CONF="$CONF_DIR/policy.json"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize
init_config() {
    mkdir -p "$CONF_DIR"
    [ ! -f "$ROUTES_CONF" ] && echo '[]' > "$ROUTES_CONF"
    [ ! -f "$POLICY_CONF" ] && echo '[]' > "$POLICY_CONF"
}

# Get current routing table
get_routing_table() {
    local table="${1:-main}"
    
    # Get routes from ip route
    local routes=$($IP route show table $table 2>/dev/null | jq -Rs 'split("\n") | map(select(length > 0))')
    
    echo "{\"table\": \"$table\", \"routes\": $routes}"
}

# Get all routing tables
get_all_tables() {
    local tables='["main", "local", "default"]'
    
    # Check for custom tables in /etc/iproute2/rt_tables
    if [ -f /etc/iproute2/rt_tables ]; then
        local custom=$(grep -v '^#' /etc/iproute2/rt_tables | grep -v '^[0-9]*[[:space:]]*\(local\|main\|default\)' | awk '{print $2}' | jq -R -s 'split("\n") | map(select(length > 0))')
        tables=$(echo "$tables" | jq ". + $custom | unique")
    fi
    
    echo "{\"tables\": $tables}"
}

# List static routes
list_routes() {
    init_config
    cat "$ROUTES_CONF"
}

# Get a single route
get_route() {
    local id="$1"
    init_config
    
    cat "$ROUTES_CONF" | jq -r ".[] | select(.id == \"$id\")" || echo '{"error": "Route not found"}'
}

# Add static route
add_route() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local dest=$(echo "$data" | jq -r '.dest')
    local gateway=$(echo "$data" | jq -r '.gateway // ""')
    local interface=$(echo "$data" | jq -r '.interface // ""')
    local metric=$(echo "$data" | jq -r '.metric // 100')
    local table=$(echo "$data" | jq -r '.table // "main"')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    
    # Validate
    if [ -z "$dest" ]; then
        echo '{"success": false, "message": "目标网络必填"}'
        return 1
    fi
    
    # Must have either gateway or interface
    if [ -z "$gateway" ] && [ -z "$interface" ]; then
        echo '{"success": false, "message": "网关或接口必填其一"}'
        return 1
    fi
    
    # Generate ID
    local id=$(echo "$dest-$gateway-$interface-$table" | tr './' '--' | tr -s '-')
    
    # Check for duplicates
    if cat "$ROUTES_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "路由已存在"}'
        return 1
    fi
    
    # Create route entry
    local new_route=$(cat << EOF
{
    "id": "$id",
    "name": "${name:-$dest}",
    "dest": "$dest",
    "gateway": "$gateway",
    "interface": "$interface",
    "metric": $metric,
    "table": "$table",
    "enabled": $enabled,
    "created_at": "$(date -Iseconds)"
}
EOF
)
    
    # Save to config
    local updated=$(cat "$ROUTES_CONF" | jq ". + [$new_route]")
    echo "$updated" > "$ROUTES_CONF"
    
    # Apply if enabled
    if [ "$enabled" = "true" ]; then
        apply_route "$id"
    fi
    
    echo "{\"success\": true, \"message\": \"路由已添加\", \"id\": \"$id\"}"
}

# Delete route
delete_route() {
    local id="$1"
    init_config
    
    # Get route info before deleting
    local route=$(cat "$ROUTES_CONF" | jq -r ".[] | select(.id == \"$id\")")
    
    # Remove from system
    if [ -n "$route" ]; then
        local dest=$(echo "$route" | jq -r '.dest')
        local table=$(echo "$route" | jq -r '.table')
        $IP route del $dest table $table 2>/dev/null
    fi
    
    # Remove from config
    local updated=$(cat "$ROUTES_CONF" | jq "map(select(.id != \"$id\"))")
    echo "$updated" > "$ROUTES_CONF"
    
    echo '{"success": true, "message": "路由已删除"}'
}

# Apply a single route
apply_route() {
    local id="$1"
    init_config
    
    local route=$(cat "$ROUTES_CONF" | jq -r ".[] | select(.id == \"$id\")")
    [ -z "$route" ] && return 1
    
    local dest=$(echo "$route" | jq -r '.dest')
    local gateway=$(echo "$route" | jq -r '.gateway')
    local interface=$(echo "$route" | jq -r '.interface')
    local metric=$(echo "$route" | jq -r '.metric')
    local table=$(echo "$route" | jq -r '.table')
    
    # Build route command
    local cmd="$IP route add $dest"
    [ -n "$gateway" ] && cmd="$cmd via $gateway"
    [ -n "$interface" ] && cmd="$cmd dev $interface"
    cmd="$cmd metric $metric table $table"
    
    # Execute
    eval $cmd 2>/dev/null && return 0 || return 1
}

# Apply all routes
apply_all_routes() {
    init_config
    
    # Flush and re-add all routes from config
    cat "$ROUTES_CONF" | jq -r '.[] | select(.enabled == true) | .id' | while read id; do
        apply_route "$id"
    done
    
    echo '{"success": true, "message": "所有路由已应用"}'
}

# Get policy routing rules
list_policy_rules() {
    init_config
    
    # Get system rules
    local system_rules=$($IP rule show | jq -Rs 'split("\n") | map(select(length > 0))')
    local config_rules=$(cat "$POLICY_CONF")
    
    echo "{\"system_rules\": $system_rules, \"config_rules\": $config_rules}"
}

# Add policy routing rule
add_policy_rule() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local from=$(echo "$data" | jq -r '.from // ""')
    local to=$(echo "$data" | jq -r '.to // ""')
    local table=$(echo "$data" | jq -r '.table')
    local priority=$(echo "$data" | jq -r '.priority // 1000')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    
    # Validate
    if [ -z "$table" ]; then
        echo '{"success": false, "message": "路由表必填"}'
        return 1
    fi
    
    # Generate ID
    local id=$(echo "rule-$from-$to-$table-$priority" | tr './' '--' | tr -s '-')
    
    # Create rule entry
    local new_rule=$(cat << EOF
{
    "id": "$id",
    "name": "${name:-Policy Rule}",
    "from": "$from",
    "to": "$to",
    "table": "$table",
    "priority": $priority,
    "enabled": $enabled,
    "created_at": "$(date -Iseconds)"
}
EOF
)
    
    # Save to config
    local updated=$(cat "$POLICY_CONF" | jq ". + [$new_rule]")
    echo "$updated" > "$POLICY_CONF"
    
    # Apply if enabled
    if [ "$enabled" = "true" ]; then
        apply_policy_rule "$id"
    fi
    
    echo "{\"success\": true, \"message\": \"策略规则已添加\", \"id\": \"$id\"}"
}

# Apply policy rule
apply_policy_rule() {
    local id="$1"
    init_config
    
    local rule=$(cat "$POLICY_CONF" | jq -r ".[] | select(.id == \"$id\")")
    [ -z "$rule" ] && return 1
    
    local from=$(echo "$rule" | jq -r '.from')
    local to=$(echo "$rule" | jq -r '.to')
    local table=$(echo "$rule" | jq -r '.table')
    local priority=$(echo "$rule" | jq -r '.priority')
    
    # Build rule command
    local cmd="$IP rule add prio $priority"
    [ -n "$from" ] && [ "$from" != "null" ] && cmd="$cmd from $from"
    [ -n "$to" ] && [ "$to" != "null" ] && cmd="$cmd to $to"
    cmd="$cmd table $table"
    
    # Execute
    eval $cmd 2>/dev/null && return 0 || return 1
}

# Delete policy rule
delete_policy_rule() {
    local id="$1"
    init_config
    
    # Get rule info
    local rule=$(cat "$POLICY_CONF" | jq -r ".[] | select(.id == \"$id\")")
    
    # Remove from system
    if [ -n "$rule" ]; then
        local from=$(echo "$rule" | jq -r '.from')
        local to=$(echo "$rule" | jq -r '.to')
        local table=$(echo "$rule" | jq -r '.table')
        local priority=$(echo "$rule" | jq -r '.priority')
        
        local cmd="$IP rule del prio $priority"
        [ -n "$from" ] && [ "$from" != "null" ] && cmd="$cmd from $from"
        [ -n "$to" ] && [ "$to" != "null" ] && cmd="$cmd to $to"
        cmd="$cmd table $table"
        
        eval $cmd 2>/dev/null
    fi
    
    # Remove from config
    local updated=$(cat "$POLICY_CONF" | jq "map(select(.id != \"$id\"))")
    echo "$updated" > "$POLICY_CONF"
    
    echo '{"success": true, "message": "策略规则已删除"}'
}

# Get network interfaces
get_interfaces() {
    local interfaces=$($IP link show | grep -E '^[0-9]+:' | awk -F: '{print $2}' | sed 's/ //g' | jq -R -s 'split("\n") | map(select(length > 0))')
    echo "{\"interfaces\": $interfaces}"
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/routes/tables)
                get_all_tables
                ;;
            /api/apps/routes/table/*)
                local table=$(echo "$PATH_INFO" | sed 's|/api/apps/routes/table/||')
                get_routing_table "$table"
                ;;
            /api/apps/routes/routes/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/routes/routes/||')
                get_route "$id"
                ;;
            /api/apps/routes/routes)
                list_routes
                ;;
            /api/apps/routes/policy)
                list_policy_rules
                ;;
            /api/apps/routes/interfaces)
                get_interfaces
                ;;
            *)
                list_routes
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/routes/routes)
                add_route
                ;;
            /api/apps/routes/apply)
                apply_all_routes
                ;;
            /api/apps/routes/policy)
                add_policy_rule
                ;;
            /api/apps/routes/policy/*/apply)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/routes/policy/\([^/]*\)/apply|\1|')
                apply_policy_rule "$id"
                echo '{"success": true, "message": "规则已应用"}'
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/routes/routes/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/routes/routes/||')
                delete_route "$id"
                ;;
            /api/apps/routes/policy/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/routes/policy/||')
                delete_policy_rule "$id"
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac