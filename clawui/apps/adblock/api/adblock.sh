#!/bin/sh
# ClawUI AdBlock App API
# DNS-based ad blocking with multiple rule sources

CONF_DIR="/etc/clawui/adblock"
RULES_DIR="$CONF_DIR/rules"
WHITELIST_CONF="$CONF_DIR/whitelist.json"
BLACKLIST_CONF="$CONF_DIR/blacklist.json"
SOURCES_CONF="$CONF_DIR/sources.json"
SETTINGS_CONF="$CONF_DIR/settings.json"
DNSMASQ_DIR="/etc/dnsmasq.d"
ADBLOCK_CONF="$DNSMASQ_DIR/adblock.conf"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize
init_config() {
    mkdir -p "$CONF_DIR"
    mkdir -p "$RULES_DIR"
    mkdir -p "$DNSMASQ_DIR"
    [ ! -f "$WHITELIST_CONF" ] && echo '[]' > "$WHITELIST_CONF"
    [ ! -f "$BLACKLIST_CONF" ] && echo '[]' > "$BLACKLIST_CONF"
    [ ! -f "$SOURCES_CONF" ] && echo '[
        {"id": "adguard", "name": "AdGuard DNS", "url": "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt", "enabled": true},
        {"id": "easylist", "name": "EasyList China", "url": "https://easylist-downloads.adblockplus.org/easylistchina.txt", "enabled": true},
        {"id": "anti-ad", "name": "Anti-AD", "url": "https://anti-ad.net/anti-ad-for-dnsmasq.conf", "enabled": false}
    ]' > "$SOURCES_CONF"
    [ ! -f "$SETTINGS_CONF" ] && echo '{"enabled": false, "update_interval": 86400, "block_type": "nxdomain"}' > "$SETTINGS_CONF"
}

# Get status
get_status() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local enabled=$(echo "$settings" | jq -r '.enabled')
    local sources=$(cat "$SOURCES_CONF")
    
    # Count blocked domains
    local blocked_count=0
    if [ -f "$ADBLOCK_CONF" ]; then
        blocked_count=$(grep -c "^address=" "$ADBLOCK_CONF" 2>/dev/null || echo 0)
    fi
    
    # Count whitelist/blacklist
    local whitelist_count=$(cat "$WHITELIST_CONF" | jq 'length')
    local blacklist_count=$(cat "$BLACKLIST_CONF" | jq 'length')
    
    # Get last update time
    local last_update=""
    if [ -f "$RULES_DIR/.last_update" ]; then
        last_update=$(cat "$RULES_DIR/.last_update")
    fi
    
    cat << EOF
{
    "enabled": $enabled,
    "blocked_count": $blocked_count,
    "whitelist_count": $whitelist_count,
    "blacklist_count": $blacklist_count,
    "last_update": "$last_update",
    "settings": $settings,
    "sources": $sources
}
EOF
}

# Update rules from sources
update_rules() {
    init_config
    
    local sources=$(cat "$SOURCES_CONF")
    local total_domains=0
    
    # Clear existing rules
    > "$ADBLOCK_CONF"
    
    # Process each enabled source
    echo "$sources" | jq -r '.[] | select(.enabled == true) | @base64' | while read source_b64; do
        local source=$(echo "$source_b64" | base64 -d)
        local id=$(echo "$source" | jq -r '.id')
        local url=$(echo "$source" | jq -r '.url')
        local name=$(echo "$source" | jq -r '.name')
        
        echo "Updating $name..."
        
        # Download rules
        local temp_file=$(mktemp)
        if curl -s --max-time 60 "$url" -o "$temp_file" 2>/dev/null; then
            # Parse rules (convert to dnsmasq format)
            local count=0
            
            # Handle different formats
            if echo "$url" | grep -q "dnsmasq"; then
                # Already in dnsmasq format
                cat "$temp_file" | grep "^address=" >> "$ADBLOCK_CONF"
                count=$(grep -c "^address=" "$temp_file" 2>/dev/null || echo 0)
            else
                # Convert hosts/ABP format to dnsmasq
                grep -E "^\|\|.*\^$" "$temp_file" | sed 's/||//;s/\^$//' | while read domain; do
                    if ! is_whitelisted "$domain"; then
                        echo "address=/$domain/0.0.0.0" >> "$ADBLOCK_CONF"
                    fi
                done
                
                # Also handle hosts format
                grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]" "$temp_file" | awk '{print $2}' | while read domain; do
                    if ! is_whitelisted "$domain"; then
                        echo "address=/$domain/0.0.0.0" >> "$ADBLOCK_CONF"
                    fi
                done
            fi
            
            echo "{\"id\": \"$id\", \"status\": \"success\", \"count\": $count}"
        else
            echo "{\"id\": \"$id\", \"status\": \"failed\"}"
        fi
        
        rm -f "$temp_file"
    done
    
    # Add custom blacklist
    cat "$BLACKLIST_CONF" | jq -r '.[]' | while read domain; do
        echo "address=/$domain/0.0.0.0" >> "$ADBLOCK_CONF"
    done
    
    # Remove whitelisted domains
    cat "$WHITELIST_CONF" | jq -r '.[]' | while read domain; do
        sed -i "/address=\/${domain}\//d" "$ADBLOCK_CONF"
    done
    
    # Remove duplicates
    sort -u "$ADBLOCK_CONF" -o "$ADBLOCK_CONF"
    
    # Save last update time
    date -Iseconds > "$RULES_DIR/.last_update"
    
    # Count total
    local total=$(grep -c "^address=" "$ADBLOCK_CONF" 2>/dev/null || echo 0)
    
    # Restart dnsmasq
    rc-service dnsmasq restart 2>/dev/null || true
    
    echo "{\"success\": true, \"message\": \"规则已更新\", \"blocked_count\": $total}"
}

# Check if domain is whitelisted
is_whitelisted() {
    local domain="$1"
    cat "$WHITELIST_CONF" | jq -e "index(\"$domain\")" >/dev/null 2>&1
}

# List sources
list_sources() {
    init_config
    cat "$SOURCES_CONF"
}

# Add source
add_source() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local url=$(echo "$data" | jq -r '.url')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    
    if [ -z "$name" ] || [ -z "$url" ]; then
        echo '{"success": false, "message": "名称和URL必填"}'
        return 1
    fi
    
    local id=$(echo "$name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    
    # Check for duplicates
    if cat "$SOURCES_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "规则源已存在"}'
        return 1
    fi
    
    local new_source=$(cat << EOF
{"id": "$id", "name": "$name", "url": "$url", "enabled": $enabled}
EOF
)
    
    local updated=$(cat "$SOURCES_CONF" | jq ". + [$new_source]")
    echo "$updated" > "$SOURCES_CONF"
    
    echo "{\"success\": true, \"message\": \"规则源已添加\", \"id\": \"$id\"}"
}

# Update source
update_source() {
    local id="$1"
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local url=$(echo "$data" | jq -r '.url // empty')
    
    local updates="{}"
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$url" ] && updates=$(echo "$updates" | jq ". + {\"url\": \"$url\"}")
    
    local updated=$(cat "$SOURCES_CONF" | jq "map(if .id == \"$id\" then . + $updates else . end)")
    echo "$updated" > "$SOURCES_CONF"
    
    echo '{"success": true, "message": "规则源已更新"}'
}

# Delete source
delete_source() {
    local id="$1"
    init_config
    
    local updated=$(cat "$SOURCES_CONF" | jq "map(select(.id != \"$id\"))")
    echo "$updated" > "$SOURCES_CONF"
    
    echo '{"success": true, "message": "规则源已删除"}'
}

# List whitelist
list_whitelist() {
    init_config
    cat "$WHITELIST_CONF"
}

# Add to whitelist
add_whitelist() {
    read -n $CONTENT_LENGTH data
    
    local domain=$(echo "$data" | jq -r '.domain')
    local comment=$(echo "$data" | jq -r '.comment // ""')
    
    if [ -z "$domain" ]; then
        echo '{"success": false, "message": "域名必填"}'
        return 1
    fi
    
    # Check if already in whitelist
    if is_whitelisted "$domain"; then
        echo '{"success": false, "message": "域名已在白名单中"}'
        return 1
    fi
    
    local updated=$(cat "$WHITELIST_CONF" | jq ". + [\"$domain\"]")
    echo "$updated" > "$WHITELIST_CONF"
    
    # Remove from adblock if present
    sed -i "/address=\/${domain}\//d" "$ADBLOCK_CONF" 2>/dev/null
    
    echo '{"success": true, "message": "已添加到白名单"}'
}

# Remove from whitelist
remove_whitelist() {
    local domain="$1"
    init_config
    
    local updated=$(cat "$WHITELIST_CONF" | jq "map(select(. != \"$domain\"))")
    echo "$updated" > "$WHITELIST_CONF"
    
    echo '{"success": true, "message": "已从白名单移除"}'
}

# List blacklist
list_blacklist() {
    init_config
    cat "$BLACKLIST_CONF"
}

# Add to blacklist
add_blacklist() {
    read -n $CONTENT_LENGTH data
    
    local domain=$(echo "$data" | jq -r '.domain')
    local comment=$(echo "$data" | jq -r '.comment // ""')
    
    if [ -z "$domain" ]; then
        echo '{"success": false, "message": "域名必填"}'
        return 1
    fi
    
    # Check if already in blacklist
    if cat "$BLACKLIST_CONF" | jq -e "index(\"$domain\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "域名已在黑名单中"}'
        return 1
    fi
    
    local updated=$(cat "$BLACKLIST_CONF" | jq ". + [\"$domain\"]")
    echo "$updated" > "$BLACKLIST_CONF"
    
    # Add to adblock
    echo "address=/$domain/0.0.0.0" >> "$ADBLOCK_CONF"
    
    echo '{"success": true, "message": "已添加到黑名单"}'
}

# Remove from blacklist
remove_blacklist() {
    local domain="$1"
    init_config
    
    local updated=$(cat "$BLACKLIST_CONF" | jq "map(select(. != \"$domain\"))")
    echo "$updated" > "$BLACKLIST_CONF"
    
    # Remove from adblock
    sed -i "/address=\/${domain}\//d" "$ADBLOCK_CONF" 2>/dev/null
    
    echo '{"success": true, "message": "已从黑名单移除"}'
}

# Get settings
get_settings() {
    init_config
    cat "$SETTINGS_CONF"
}

# Update settings
update_settings() {
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local update_interval=$(echo "$data" | jq -r '.update_interval // empty')
    local block_type=$(echo "$data" | jq -r '.block_type // empty')
    
    local updates="{}"
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$update_interval" ] && updates=$(echo "$updates" | jq ". + {\"update_interval\": $update_interval}")
    [ -n "$block_type" ] && updates=$(echo "$updates" | jq ". + {\"block_type\": \"$block_type\"}")
    
    local updated=$(cat "$SETTINGS_CONF" | jq ". + $updates")
    echo "$updated" > "$SETTINGS_CONF"
    
    # Enable/disable in dnsmasq
    if [ "$enabled" = "true" ]; then
        # Add dnsmasq config include
        echo "conf-dir=$DNSMASQ_DIR,*.conf" >> /etc/dnsmasq.conf 2>/dev/null
        rc-service dnsmasq restart 2>/dev/null || true
    else
        # Remove adblock conf temporarily
        mv "$ADBLOCK_CONF" "${ADBLOCK_CONF}.bak" 2>/dev/null
        rc-service dnsmasq restart 2>/dev/null || true
        mv "${ADBLOCK_CONF}.bak" "$ADBLOCK_CONF" 2>/dev/null
    fi
    
    echo '{"success": true, "message": "设置已保存"}'
}

# Test if domain is blocked
test_domain() {
    local domain=$(echo "$QUERY_STRING" | grep -o 'domain=[^&]*' | cut -d= -f2)
    
    if [ -z "$domain" ]; then
        echo '{"success": false, "message": "域名必填"}'
        return 1
    fi
    
    local blocked="false"
    local in_whitelist="false"
    local in_blacklist="false"
    
    if grep -q "address=/${domain}/" "$ADBLOCK_CONF" 2>/dev/null; then
        blocked="true"
    fi
    
    if is_whitelisted "$domain"; then
        in_whitelist="true"
        blocked="false"
    fi
    
    if cat "$BLACKLIST_CONF" | jq -e "index(\"$domain\")" >/dev/null 2>&1; then
        in_blacklist="true"
        blocked="true"
    fi
    
    cat << EOF
{
    "domain": "$domain",
    "blocked": $blocked,
    "in_whitelist": $in_whitelist,
    "in_blacklist": $in_blacklist
}
EOF
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/adblock/sources)
                list_sources
                ;;
            /api/apps/adblock/whitelist)
                list_whitelist
                ;;
            /api/apps/adblock/blacklist)
                list_blacklist
                ;;
            /api/apps/adblock/settings)
                get_settings
                ;;
            /api/apps/adblock/test)
                test_domain
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/adblock/update)
                update_rules
                ;;
            /api/apps/adblock/sources)
                add_source
                ;;
            /api/apps/adblock/sources/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/adblock/sources/||')
                update_source "$id"
                ;;
            /api/apps/adblock/whitelist)
                add_whitelist
                ;;
            /api/apps/adblock/blacklist)
                add_blacklist
                ;;
            /api/apps/adblock/settings)
                update_settings
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/adblock/sources/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/adblock/sources/||')
                delete_source "$id"
                ;;
            /api/apps/adblock/whitelist/*)
                local domain=$(echo "$PATH_INFO" | sed 's|/api/apps/adblock/whitelist/||')
                remove_whitelist "$domain"
                ;;
            /api/apps/adblock/blacklist/*)
                local domain=$(echo "$PATH_INFO" | sed 's|/api/apps/adblock/blacklist/||')
                remove_blacklist "$domain"
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