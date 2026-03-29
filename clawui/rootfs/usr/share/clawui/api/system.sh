#!/bin/sh
# ClawUI System API
# System settings and operations

# Get system info
get_system_info() {
    cat << EOF
{
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "alpine": "$(cat /etc/alpine-release 2>/dev/null || echo 'unknown')",
    "uptime": "$(uptime -p 2>/dev/null || uptime)",
    "date": "$(date)",
    "timezone": "$(cat /etc/timezone 2>/dev/null || echo 'UTC')",
    "cpu": {
        "model": "$(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2 | xargs)",
        "cores": $(nproc),
        "temperature": "$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')°C"
    },
    "storage": {
        "total": "$(df -h / | tail -1 | awk '{print $2}')",
        "used": "$(df -h / | tail -1 | awk '{print $3}')",
        "available": "$(df -h / | tail -1 | awk '{print $4}')"
    }
}
EOF
}

# Get system logs
get_logs() {
    local lines="${1:-50}"
    echo "["
    dmesg | tail -$lines | while read line; do
        echo "\"$line\","
    done | sed '$ s/,$//'
    echo "]"
}

# Get services
get_services() {
    echo "["
    for service in /etc/init.d/*; do
        [ -f "$service" ] || continue
        local name=$(basename $service)
        local status=$(/sbin/rc-service $name status 2>/dev/null || echo "stopped")
        local enabled=$(/sbin/rc-update show default 2>/dev/null | grep -q "^$name" && echo "true" || echo "false")
        echo "{\"name\": \"$name\", \"status\": \"$status\", \"enabled\": $enabled},"
    done | sed '$ s/,$//'
    echo "]"
}

# Update hostname
set_hostname() {
    read -n $CONTENT_LENGTH data
    local hostname=$(echo "$data" | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$hostname" ]; then
        echo "$hostname" > /etc/hostname
        hostname "$hostname"
        echo "{\"success\": true, \"hostname\": \"$hostname\"}"
    else
        echo '{"success": false, "message": "No hostname provided"}'
    fi
}

# Set timezone
set_timezone() {
    read -n $CONTENT_LENGTH data
    local tz=$(echo "$data" | grep -o '"timezone":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$tz" ]; then
        setup-timezone -z "$tz" 2>/dev/null || echo "$tz" > /etc/timezone
        echo "{\"success\": true, \"timezone\": \"$tz\"}"
    else
        echo '{"success": false, "message": "No timezone provided"}'
    fi
}

# Reboot
do_reboot() {
    echo '{"success": true, "message": "Rebooting..."}'
    reboot &
}

# Factory reset
do_factory_reset() {
    echo '{"success": true, "message": "Factory reset in progress..."}'
    /usr/sbin/factory-reset &
}

# Backup config
backup_config() {
    local file="/tmp/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$file" /etc 2>/dev/null
    echo "{\"success\": true, \"file\": \"$file\"}"
}

# Restore config
restore_config() {
    echo '{"success": false, "message": "Upload not implemented"}'
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/system/logs)
                local lines=$(echo "$QUERY_STRING" | grep -o 'lines=[0-9]*' | cut -d= -f2)
                get_logs "${lines:-50}"
                ;;
            /api/system/services)
                get_services
                ;;
            *)
                get_system_info
                ;;
        esac
        ;;
    POST)
        case "$PATH_INFO" in
            /api/system/hostname)
                set_hostname
                ;;
            /api/system/timezone)
                set_timezone
                ;;
            /api/system/reboot)
                do_reboot
                ;;
            /api/system/factory-reset)
                do_factory_reset
                ;;
            /api/system/backup)
                backup_config
                ;;
            /api/system/restore)
                restore_config
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