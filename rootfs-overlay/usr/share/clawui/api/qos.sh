#!/bin/sh
# ClawUI QoS API
# Traffic control configuration

# Get QoS status
get_qos_status() {
    local enabled="false"
    local download="0"
    local upload="0"
    
    if [ -f /etc/qos.conf ]; then
        enabled="true"
        download=$(grep DOWNLOAD /etc/qos.conf | cut -d= -f2)
        upload=$(grep UPLOAD /etc/qos.conf | cut -d= -f2)
    fi
    
    cat << EOF
{
    "enabled": $enabled,
    "download": ${download:-0},
    "upload": ${upload:-0},
    "rules": []
}
EOF
}

# Set QoS
set_qos() {
    read -n $CONTENT_LENGTH data
    
    local download=$(echo "$data" | grep -o '"download":[0-9]*' | cut -d: -f2)
    local upload=$(echo "$data" | grep -o '"upload":[0-9]*' | cut -d: -f2)
    
    if [ -n "$download" ] && [ -n "$upload" ]; then
        /usr/sbin/qos set "$download" "$upload"
        echo '{"success": true}'
    else
        echo '{"success": false}'
    fi
}

# Clear QoS
clear_qos() {
    /usr/sbin/qos clear
    echo '{"success": true}'
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        get_qos_status
        ;;
    POST)
        case "$PATH_INFO" in
            /api/qos/clear)
                clear_qos
                ;;
            *)
                set_qos
                ;;
        esac
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac