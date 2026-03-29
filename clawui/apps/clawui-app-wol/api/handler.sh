#!/bin/sh
# Wake-on-LAN API Handler
ACTION="$1"; shift
WOL_DEVICES="/etc/wol/devices.json"
case "$ACTION" in
    wake)
        read -r INPUT
        MAC=$(echo "$INPUT" | sed -n 's/.*"mac"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        IFACE=$(echo "$INPUT" | sed -n 's/.*"iface"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        if command -v etherwake > /dev/null 2>&1; then
            etherwake -i "${IFACE:-br-lan}" "$MAC" 2>/dev/null && echo '{"success": true}' || echo '{"success": false, "error": "Failed to send"}'
        else
            echo '{"success": false, "error": "etherwake not installed"}'
        fi
        ;;
    devices)
        if [ -f "$WOL_DEVICES" ]; then
            cat "$WOL_DEVICES"
        else
            echo '{"devices": []}'
        fi
        ;;
    save)
        read -r INPUT
        mkdir -p /etc/wol
        echo "$INPUT" > "$WOL_DEVICES"
        echo '{"success": true}'
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
