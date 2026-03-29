#!/bin/sh
# ClawUI Status API
# System status and statistics

# Get system info
get_uptime() {
    cat /proc/uptime | awk '{print int($1)}'
}

get_memory() {
    local mem=$(free -m | grep Mem)
    local total=$(echo $mem | awk '{print $2}')
    local used=$(echo $mem | awk '{print $3}')
    local free=$(echo $mem | awk '{print $4}')
    echo "{\"total\": $total, \"used\": $used, \"free\": $free}"
}

get_cpu() {
    local cpu=$(top -bn1 | grep "CPU:" | head -1)
    local usage=$(echo "$cpu" | sed 's/.*\([0-9]*\.[0-9]*\)% id.*/\1/')
    echo "scale=1; 100 - $usage" | bc 2>/dev/null || echo "0"
}

get_load() {
    cat /proc/loadavg | awk '{print $1", "$2", "$3}'
}

get_network_stats() {
    local wan_rx=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null || echo 0)
    local wan_tx=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null || echo 0)
    echo "{\"rx\": $wan_rx, \"tx\": $wan_tx}"
}

get_clients() {
    local count=0
    [ -f /var/lib/misc/dnsmasq.leases ] && count=$(wc -l < /var/lib/misc/dnsmasq.leases)
    echo "$count"
}

# Build response
case "$REQUEST_METHOD" in
    GET)
        cat << EOF
{
    "uptime": $(get_uptime),
    "memory": $(get_memory),
    "cpu": $(get_cpu),
    "load": "$(get_load)",
    "network": $(get_network_stats),
    "clients": $(get_clients),
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "alpine": "$(cat /etc/alpine-release 2>/dev/null || echo 'unknown')"
}
EOF
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac