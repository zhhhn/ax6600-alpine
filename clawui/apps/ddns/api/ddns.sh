#!/bin/sh
# ClawUI DDNS App API
# Dynamic DNS service management

CONF_DIR="/etc/clawui/ddns"
SERVICES_CONF="$CONF_DIR/services.json"
LOG_FILE="/var/log/ddns.log"
DDNS_SCRIPT="/usr/sbin/clawui-ddns"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize config
init_config() {
    mkdir -p "$CONF_DIR"
    [ ! -f "$SERVICES_CONF" ] && echo '[]' > "$SERVICES_CONF"
}

# Get current public IP
get_public_ip() {
    local ip=""
    
    # Try multiple services
    ip=$(curl -s -4 --max-time 5 https://api.ipify.org 2>/dev/null) || \
    ip=$(curl -s -4 --max-time 5 https://ifconfig.me 2>/dev/null) || \
    ip=$(curl -s -4 --max-time 5 https://ip.sb 2>/dev/null) || \
    ip=$(curl -s -4 --max-time 5 http://members.3322.org/dyndns/getip 2>/dev/null)
    
    echo "$ip"
}

# Get DDNS status
get_status() {
    init_config
    
    local services=$(cat "$SERVICES_CONF")
    local running_count=$(echo "$services" | jq '[.[] | select(.enabled == true)] | length')
    local total_count=$(echo "$services" | jq 'length')
    local public_ip=$(get_public_ip)
    
    # Check if ddns service is running
    local service_running="false"
    if pgrep -f clawui-ddns &>/dev/null; then
        service_running="true"
    fi
    
    cat << EOF
{
    "public_ip": "$public_ip",
    "services_count": $total_count,
    "active_count": $running_count,
    "service_running": $service_running,
    "last_update": "$(stat -c %y "$LOG_FILE" 2>/dev/null || echo '')"
}
EOF
}

# List all DDNS services
list_services() {
    init_config
    cat "$SERVICES_CONF"
}

# Get a single service
get_service() {
    local id="$1"
    init_config
    
    cat "$SERVICES_CONF" | jq -r ".[] | select(.id == \"$id\")" || echo '{"error": "Service not found"}'
}

# Add DDNS service
add_service() {
    read -n $CONTENT_LENGTH data
    
    local name=$(echo "$data" | jq -r '.name')
    local provider=$(echo "$data" | jq -r '.provider')
    local domain=$(echo "$data" | jq -r '.domain')
    local subdomain=$(echo "$data" | jq -r '.subdomain // "@"')
    local access_key=$(echo "$data" | jq -r '.access_key // ""')
    local secret_key=$(echo "$data" | jq -r '.secret_key // ""')
    local ttl=$(echo "$data" | jq -r '.ttl // 600')
    local interval=$(echo "$data" | jq -r '.interval // 300')
    local enabled=$(echo "$data" | jq -r '.enabled // true')
    
    # Validate required fields
    if [ -z "$domain" ] || [ -z "$provider" ]; then
        echo '{"success": false, "message": "域名和服务商必填"}'
        return 1
    fi
    
    # Generate ID
    local id=$(echo "$provider-$domain-$subdomain" | tr '.' '-' | tr '@' 'root')
    
    # Check for duplicates
    if cat "$SERVICES_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "该服务已存在"}'
        return 1
    fi
    
    # Create service entry
    local new_service=$(cat << EOF
{
    "id": "$id",
    "name": "${name:-$subdomain.$domain}",
    "provider": "$provider",
    "domain": "$domain",
    "subdomain": "$subdomain",
    "access_key": "$access_key",
    "secret_key": "***",
    "ttl": $ttl,
    "interval": $interval,
    "enabled": $enabled,
    "last_ip": "",
    "last_update": "",
    "status": "pending",
    "created_at": "$(date -Iseconds)"
}
EOF
)
    
    # Save secret key separately
    echo "$secret_key" > "$CONF_DIR/${id}.secret"
    chmod 600 "$CONF_DIR/${id}.secret"
    
    # Update config
    local updated=$(cat "$SERVICES_CONF" | jq ". + [$new_service]")
    echo "$updated" > "$SERVICES_CONF"
    
    echo "{\"success\": true, \"message\": \"DDNS 服务已添加\", \"id\": \"$id\"}"
}

# Update service
update_service() {
    local id="$1"
    read -n $CONTENT_LENGTH data
    
    init_config
    
    # Check if service exists
    if ! cat "$SERVICES_CONF" | jq -e ".[] | select(.id == \"$id\")" >/dev/null 2>&1; then
        echo '{"success": false, "message": "服务不存在"}'
        return 1
    fi
    
    # Parse updates
    local name=$(echo "$data" | jq -r '.name // empty')
    local enabled=$(echo "$data" | jq -r '.enabled // empty')
    local interval=$(echo "$data" | jq -r '.interval // empty')
    local access_key=$(echo "$data" | jq -r '.access_key // empty')
    local secret_key=$(echo "$data" | jq -r '.secret_key // empty')
    
    # Build update JSON
    local updates="{}"
    [ -n "$name" ] && updates=$(echo "$updates" | jq ". + {\"name\": \"$name\"}")
    [ -n "$enabled" ] && updates=$(echo "$updates" | jq ". + {\"enabled\": $enabled}")
    [ -n "$interval" ] && updates=$(echo "$updates" | jq ". + {\"interval\": $interval}")
    [ -n "$access_key" ] && updates=$(echo "$updates" | jq ". + {\"access_key\": \"$access_key\"}")
    
    # Update secret if provided
    if [ -n "$secret_key" ]; then
        echo "$secret_key" > "$CONF_DIR/${id}.secret"
    fi
    
    # Update config
    local updated=$(cat "$SERVICES_CONF" | jq "map(if .id == \"$id\" then . + $updates else . end)")
    echo "$updated" > "$SERVICES_CONF"
    
    echo '{"success": true, "message": "服务已更新"}'
}

# Delete service
delete_service() {
    local id="$1"
    init_config
    
    # Remove from config
    local updated=$(cat "$SERVICES_CONF" | jq "map(select(.id != \"$id\"))")
    echo "$updated" > "$SERVICES_CONF"
    
    # Remove secret
    rm -f "$CONF_DIR/${id}.secret"
    
    echo '{"success": true, "message": "服务已删除"}'
}

# Force update a service
force_update() {
    local id="$1"
    init_config
    
    local service=$(cat "$SERVICES_CONF" | jq -r ".[] | select(.id == \"$id\")")
    if [ -z "$service" ]; then
        echo '{"success": false, "message": "服务不存在"}'
        return 1
    fi
    
    # Get current IP
    local current_ip=$(get_public_ip)
    
    # Get service details
    local provider=$(echo "$service" | jq -r '.provider')
    local domain=$(echo "$service" | jq -r '.domain')
    local subdomain=$(echo "$service" | jq -r '.subdomain')
    local access_key=$(echo "$service" | jq -r '.access_key')
    local secret_key=$(cat "$CONF_DIR/${id}.secret" 2>/dev/null)
    
    # Update DNS record based on provider
    local result=""
    case "$provider" in
        aliyun)
            result=$(update_aliyun "$domain" "$subdomain" "$current_ip" "$access_key" "$secret_key")
            ;;
        cloudflare)
            result=$(update_cloudflare "$domain" "$subdomain" "$current_ip" "$access_key" "$secret_key")
            ;;
        dnspod|tencent)
            result=$(update_dnspod "$domain" "$subdomain" "$current_ip" "$access_key" "$secret_key")
            ;;
        *)
            result="Provider not implemented"
            ;;
    esac
    
    # Update service status
    local status="success"
    if echo "$result" | grep -qi "error\|fail"; then
        status="error"
    fi
    
    local updated=$(cat "$SERVICES_CONF" | jq "map(if .id == \"$id\" then . + {\"last_ip\": \"$current_ip\", \"last_update\": \"$(date -Iseconds)\", \"status\": \"$status\"} else . end)")
    echo "$updated" > "$SERVICES_CONF"
    
    # Log
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$id] IP: $current_ip, Result: $result" >> "$LOG_FILE"
    
    echo "{\"success\": true, \"message\": \"更新完成\", \"ip\": \"$current_ip\", \"result\": \"$result\"}"
}

# Aliyun DNS update
update_aliyun() {
    local domain="$1"
    local subdomain="$2"
    local ip="$3"
    local access_key="$4"
    local secret_key="$5"
    
    # Implementation using Aliyun API
    # This is a simplified version
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local nonce=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    
    # Use aliyun-cli if available
    if command -v aliyun &>/dev/null; then
        aliyun alidns AddDomainRecord \
            --DomainName "$domain" \
            --RR "$subdomain" \
            --Type A \
            --Value "$ip" \
            --AccessKeyId "$access_key" \
            --AccessKeySecret "$secret_key" 2>&1 && \
            echo "Success" || echo "Failed"
    else
        echo "Aliyun CLI not installed"
    fi
}

# Cloudflare DNS update
update_cloudflare() {
    local domain="$1"
    local subdomain="$2"
    local ip="$3"
    local api_token="$4"
    local unused="$5"
    
    # Get zone ID
    local zone_id=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones?name=$domain" \
        -H "Authorization: Bearer $api_token" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')
    
    if [ -z "$zone_id" ] || [ "$zone_id" = "null" ]; then
        echo "Failed to get zone ID"
        return 1
    fi
    
    # Get record ID
    local record_name="${subdomain}.${domain}"
    [ "$subdomain" = "@" ] && record_name="$domain"
    
    local record_id=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" \
        -H "Authorization: Bearer $api_token" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')
    
    # Update or create record
    if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        # Update existing
        curl -s -X PUT \
            "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
            -H "Authorization: Bearer $api_token" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$subdomain\",\"content\":\"$ip\",\"ttl\":120}" | jq -r '.success' && \
            echo "Success" || echo "Failed"
    else
        # Create new
        curl -s -X POST \
            "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
            -H "Authorization: Bearer $api_token" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$subdomain\",\"content\":\"$ip\",\"ttl\":120}" | jq -r '.success' && \
            echo "Success" || echo "Failed"
    fi
}

# DNSPod update
update_dnspod() {
    local domain="$1"
    local subdomain="$2"
    local ip="$3"
    local secret_id="$4"
    local secret_key="$5"
    
    # Use DNSPod API
    local result=$(curl -s -X POST "https://dnsapi.cn/Record.List" \
        -d "login_token=$secret_id,$secret_key" \
        -d "format=json" \
        -d "domain=$domain" \
        -d "sub_domain=$subdomain")
    
    local record_id=$(echo "$result" | jq -r '.records[0].id // empty')
    
    if [ -n "$record_id" ]; then
        curl -s -X POST "https://dnsapi.cn/Record.Modify" \
            -d "login_token=$secret_id,$secret_key" \
            -d "format=json" \
            -d "domain=$domain" \
            -d "record_id=$record_id" \
            -d "sub_domain=$subdomain" \
            -d "record_type=A" \
            -d "record_line=默认" \
            -d "value=$ip" | jq -r '.status.message' && \
            echo "Success" || echo "Failed"
    else
        curl -s -X POST "https://dnsapi.cn/Record.Create" \
            -d "login_token=$secret_id,$secret_key" \
            -d "format=json" \
            -d "domain=$domain" \
            -d "sub_domain=$subdomain" \
            -d "record_type=A" \
            -d "record_line=默认" \
            -d "value=$ip" | jq -r '.status.message' && \
            echo "Success" || echo "Failed"
    fi
}

# Get DDNS logs
get_logs() {
    local lines=$(echo "$QUERY_STRING" | grep -o 'lines=[0-9]*' | cut -d= -f2)
    lines=${lines:-50}
    
    local logs=$(tail -$lines "$LOG_FILE" 2>/dev/null | jq -Rs '.')
    
    echo "{\"logs\": $logs}"
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/ddns/services/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/ddns/services/||')
                get_service "$id"
                ;;
            /api/apps/ddns/services)
                list_services
                ;;
            /api/apps/ddns/logs)
                get_logs
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/ddns/services)
                add_service
                ;;
            /api/apps/ddns/services/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/ddns/services/||')
                update_service "$id"
                ;;
            /api/apps/ddns/services/*/update)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/ddns/services/\([^/]*\)/update|\1|')
                force_update "$id"
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/ddns/services/*)
                local id=$(echo "$PATH_INFO" | sed 's|/api/apps/ddns/services/||')
                delete_service "$id"
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