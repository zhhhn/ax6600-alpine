#!/bin/sh
# ClawUI Wireless API
# WiFi configuration and status

# Get wireless status
get_wireless_status() {
    local status2g="disabled"
    local status5g="disabled"
    local ssid2g=""
    local ssid5g=""
    local clients2g=0
    local clients5g=0
    
    # Check 2.4GHz
    if pgrep -f "hostapd.*wlan0" > /dev/null; then
        status2g="enabled"
        ssid2g=$(grep '^ssid=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
        clients2g=$(iw dev wlan0 station dump 2>/dev/null | grep Station | wc -l)
    fi
    
    # Check 5GHz
    if pgrep -f "hostapd.*wlan1" > /dev/null; then
        status5g="enabled"
        ssid5g=$(grep '^ssid=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2)
        clients5g=$(iw dev wlan1 station dump 2>/dev/null | grep Station | wc -l)
    fi
    
    cat << EOF
{
    "2g": {
        "status": "$status2g",
        "ssid": "$ssid2g",
        "channel": "$(grep '^channel=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2 || echo 'auto')",
        "clients": $clients2g
    },
    "5g": {
        "status": "$status5g",
        "ssid": "$ssid5g",
        "channel": "$(grep '^channel=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2 || echo 'auto')",
        "clients": $clients5g
    }
}
EOF
}

# Get wireless config
get_wireless_config() {
    cat << EOF
{
    "2g": {
        "ssid": "$(grep '^ssid=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)",
        "channel": "$(grep '^channel=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)",
        "encryption": "$(grep '^wpa=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)",
        "hidden": "$(grep '^ignore_broadcast_ssid=' /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2 || echo '0')"
    },
    "5g": {
        "ssid": "$(grep '^ssid=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2)",
        "channel": "$(grep '^channel=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2)",
        "encryption": "$(grep '^wpa=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2)",
        "hidden": "$(grep '^ignore_broadcast_ssid=' /etc/hostapd/hostapd-5g.conf 2>/dev/null | cut -d= -f2 || echo '0')"
    }
}
EOF
}

# Update wireless config
update_wireless_config() {
    read -n $CONTENT_LENGTH data
    
    local band=$(echo "$data" | grep -o '"band":"[^"]*"' | cut -d'"' -f4)
    local ssid=$(echo "$data" | grep -o '"ssid":"[^"]*"' | cut -d'"' -f4)
    local password=$(echo "$data" | grep -o '"password":"[^"]*"' | cut -d'"' -f4)
    local channel=$(echo "$data" | grep -o '"channel":"[^"]*"' | cut -d'"' -f4)
    
    local conf_file="/etc/hostapd/hostapd.conf"
    [ "$band" = "5g" ] && conf_file="/etc/hostapd/hostapd-5g.conf"
    
    if [ -f "$conf_file" ]; then
        [ -n "$ssid" ] && sed -i "s/^ssid=.*/ssid=$ssid/" "$conf_file"
        [ -n "$password" ] && sed -i "s/^wpa_passphrase=.*/wpa_passphrase=$password/" "$conf_file"
        [ -n "$channel" ] && sed -i "s/^channel=.*/channel=$channel/" "$conf_file"
        
        # Restart WiFi
        /usr/sbin/wifi restart 2>/dev/null &
        
        echo '{"success": true, "message": "Wireless config updated"}'
    else
        echo '{"success": false, "message": "Config file not found"}'
    fi
}

# Scan WiFi
scan_wireless() {
    local iface="wlan0"
    [ -n "$(echo "$QUERY_STRING" | grep '5g')" ] && iface="wlan1"
    
    ip link set $iface up 2>/dev/null
    iw dev $iface scan 2>/dev/null | awk '
        /BSS/ { if (ssid != "") print ssid "," mac "," channel "," signal }
        /SSID:/ { ssid=$2 }
        /signal:/ { signal=$2 }
        /DS Parameter set/ { getline; channel=$2 }
        /BSSID:/ { mac=$2 }
    ' | head -20 | while read line; do
        IFS=',' read -r ssid mac channel signal <<< "$line"
        [ -n "$ssid" ] && echo "{\"ssid\": \"$ssid\", \"mac\": \"$mac\", \"channel\": \"$channel\", \"signal\": \"$signal\"},"
    done
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/wireless/scan)
                echo "["
                scan_wireless | sed '$ s/,$//'
                echo "]"
                ;;
            /api/wireless/config)
                get_wireless_config
                ;;
            *)
                get_wireless_status
                ;;
        esac
        ;;
    POST)
        update_wireless_config
        ;;
    PUT)
        # Toggle WiFi
        read -n $CONTENT_LENGTH data
        local action=$(echo "$data" | grep -o '"action":"[^"]*"' | cut -d'"' -f4)
        
        case "$action" in
            enable) /usr/sbin/wifi up ;;
            disable) /usr/sbin/wifi down ;;
        esac
        
        echo "{\"success\": true, \"action\": \"$action\"}"
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac