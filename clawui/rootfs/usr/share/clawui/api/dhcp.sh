#!/bin/sh
# ClawUI DHCP/DNS API
# dnsmasq configuration

# Get DHCP leases
get_leases() {
    echo "["
    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        awk '{
            printf "{\"mac\": \"%s\", \"ip\": \"%s\", \"hostname\": \"%s\", \"time\": \"%s\"},\n", $2, $3, $4, $1
        }' /var/lib/misc/dnsmasq.leases | sed '$ s/,$//'
    fi
    echo "]"
}

# Get DHCP config
get_dhcp_config() {
    cat << EOF
{
    "enabled": true,
    "start": "$(grep dhcp-range /etc/dnsmasq.conf 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)",
    "end": "$(grep dhcp-range /etc/dnsmasq.conf 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | tail -1)",
    "leasetime": "$(grep dhcp-range /etc/dnsmasq.conf 2>/dev/null | grep -oP '\d+h' || echo '12h')",
    "gateway": "$(grep dhcp-option=3 /etc/dnsmasq.conf 2>/dev/null | cut -d, -f2 || echo '192.168.1.1')"
}
EOF
}

# Get DNS config
get_dns_config() {
    cat << EOF
{
    "servers": [$(grep ^server= /etc/dnsmasq.conf 2>/dev/null | cut -d= -f2 | awk '{printf "\"%s\",", $1}' | sed 's/,$//')],
    "cache_size": $(grep cache-size /etc/dnsmasq.conf 2>/dev/null | cut -d= -f2 || echo '1000')
}
EOF
}

# Update DHCP config
update_dhcp_config() {
    read -n $CONTENT_LENGTH data
    
    local start=$(echo "$data" | grep -o '"start":"[^"]*"' | cut -d'"' -f4)
    local end=$(echo "$data" | grep -o '"end":"[^"]*"' | cut -d'"' -f4)
    local leasetime=$(echo "$data" | grep -o '"leasetime":"[^"]*"' | cut -d'"' -f4)
    
    # Update dnsmasq.conf
    if [ -n "$start" ] && [ -n "$end" ]; then
        sed -i "s/^dhcp-range=.*/dhcp-range=$start,$end,255.255.255.0,$leasetime/" /etc/dnsmasq.conf
        rc-service dnsmasq restart
        echo '{"success": true}'
    else
        echo '{"success": false, "message": "Invalid parameters"}'
    fi
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/dhcp/leases)
                get_leases
                ;;
            /api/dhcp/config)
                get_dhcp_config
                ;;
            /api/dns/config)
                get_dns_config
                ;;
            *)
                get_dhcp_config
                ;;
        esac
        ;;
    POST)
        update_dhcp_config
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac