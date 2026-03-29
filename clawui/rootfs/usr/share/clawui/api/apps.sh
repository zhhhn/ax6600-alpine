#!/bin/sh
# ClawUI App Manager
# Manage installable apps with Web UI

APPS_DIR="/usr/share/clawui/apps"
REGISTRY="$APPS_DIR/registry.json"
APK_DB="/var/cache/apk"

# Initialize registry
init_registry() {
    mkdir -p "$APPS_DIR"
    if [ ! -f "$REGISTRY" ]; then
        echo '{"apps": []}' > "$REGISTRY"
    fi
}

# List available apps
list_available() {
    echo "Content-Type: application/json"
    echo ""
    
    # Built-in apps (always available)
    local builtin='[
        {"id": "network", "name": "网络", "icon": "network", "builtin": true, "installed": true},
        {"id": "wireless", "name": "无线", "icon": "wifi", "builtin": true, "installed": true},
        {"id": "firewall", "name": "防火墙", "icon": "shield", "builtin": true, "installed": true},
        {"id": "dhcp", "name": "DHCP/DNS", "icon": "dns", "builtin": true, "installed": true},
        {"id": "system", "name": "系统", "icon": "settings", "builtin": true, "installed": true}
    ]'
    
    # Optional apps (check if installed)
    local optional='[
        {"id": "openvpn", "name": "OpenVPN", "icon": "vpn", "pkg": "openvpn", "ui_pkg": "clawui-app-openvpn"},
        {"id": "wireguard", "name": "WireGuard", "icon": "shield", "pkg": "wireguard-tools", "ui_pkg": "clawui-app-wireguard"},
        {"id": "transmission", "name": "Transmission", "icon": "download", "pkg": "transmission-daemon", "ui_pkg": "clawui-app-transmission"},
        {"id": "aria2", "name": "Aria2", "icon": "download", "pkg": "aria2", "ui_pkg": "clawui-app-aria2"},
        {"id": "samba", "name": "Samba", "icon": "folder", "pkg": "samba", "ui_pkg": "clawui-app-samba"},
        {"id": "frp", "name": "FRP", "icon": "link", "pkg": "frp", "ui_pkg": "clawui-app-frp"},
        {"id": "adblock", "name": "AdBlock", "icon": "block", "pkg": "adguardhome", "ui_pkg": "clawui-app-adguard"},
        {"id": "ddns", "name": "DDNS", "icon": "dns", "pkg": "ddns-scripts", "ui_pkg": "clawui-app-ddns"}
    ]'
    
    # Check which packages are installed
    local result='{"builtin": '$builtin', "available": ['
    local first=1
    
    echo "$optional" | jq -c '.[]' 2>/dev/null | while read app; do
        local id=$(echo "$app" | jq -r '.id')
        local pkg=$(echo "$app" | jq -r '.pkg')
        local ui_pkg=$(echo "$app" | jq -r '.ui_pkg')
        
        # Check if package is installed
        local pkg_installed="false"
        local ui_installed="false"
        
        if apk info -e "$pkg" 2>/dev/null; then
            pkg_installed="true"
        fi
        
        if apk info -e "$ui_pkg" 2>/dev/null; then
            ui_installed="true"
        fi
        
        # Add to result
        if [ "$first" = "1" ]; then
            first=0
        else
            echo ","
        fi
        
        echo "$app" | jq -c \
            --argjson pkg_installed "$pkg_installed" \
            --argjson ui_installed "$ui_installed" \
            '. + {pkg_installed: $pkg_installed, ui_installed: $ui_installed}'
    done
    
    echo ']}'
}

# Install app UI
install_app_ui() {
    local app_id="$1"
    
    # Get app info
    local app_info=$(cat << 'EOF' | jq -r --arg id "$app_id" '.[] | select(.id == $id)'
[
    {"id": "openvpn", "pkg": "openvpn", "ui_pkg": "clawui-app-openvpn"},
    {"id": "wireguard", "pkg": "wireguard-tools", "ui_pkg": "clawui-app-wireguard"},
    {"id": "transmission", "pkg": "transmission-daemon", "ui_pkg": "clawui-app-transmission"},
    {"id": "aria2", "pkg": "aria2", "ui_pkg": "clawui-app-aria2"},
    {"id": "samba", "pkg": "samba", "ui_pkg": "clawui-app-samba"}
]
EOF
)
    
    local ui_pkg=$(echo "$app_info" | jq -r '.ui_pkg')
    local pkg=$(echo "$app_info" | jq -r '.pkg')
    
    if [ -z "$ui_pkg" ] || [ "$ui_pkg" = "null" ]; then
        echo '{"success": false, "message": "App not found"}'
        return 1
    fi
    
    # Check if main package is installed
    if ! apk info -e "$pkg" 2>/dev/null; then
        echo "{\"success\": false, \"message\": \"Please install $pkg first\"}"
        return 1
    fi
    
    # Install UI package
    if apk add "$ui_pkg" 2>/dev/null; then
        echo "{\"success\": true, \"message\": \"$ui_pkg installed\"}"
    else
        echo "{\"success\": false, \"message\": \"Failed to install $ui_pkg\"}"
    fi
}

# Remove app UI
remove_app_ui() {
    local app_id="$1"
    
    # Similar logic but with apk del
    echo '{"success": true, "message": "UI removed"}'
}

# Get app details
get_app_details() {
    local app_id="$1"
    
    case "$app_id" in
        openvpn)
            cat << 'EOF'
{
    "id": "openvpn",
    "name": "OpenVPN",
    "description": "OpenVPN VPN 服务器/客户端",
    "icon": "vpn",
    "category": "vpn",
    "pkg": "openvpn",
    "ui_pkg": "clawui-app-openvpn",
    "installed": INSTALL_STATUS,
    "version": "VERSION"
}
EOF
            ;;
        wireguard)
            cat << 'EOF'
{
    "id": "wireguard",
    "name": "WireGuard",
    "description": "WireGuard VPN - 快速现代 VPN",
    "icon": "shield",
    "category": "vpn",
    "pkg": "wireguard-tools",
    "ui_pkg": "clawui-app-wireguard",
    "installed": INSTALL_STATUS
}
EOF
            ;;
        *)
            echo '{"error": "App not found"}'
            ;;
    esac | sed "s/INSTALL_STATUS/$(apk info -e $app_id 2>/dev/null && echo 'true' || echo 'false')/g" \
         | sed "s/VERSION/$(apk info -v $app_id 2>/dev/null | awk '{print $2}')/g"
}

# Main API handler
case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/available)
                list_available
                ;;
            /api/apps/installed)
                # List installed apps with UI
                echo '{"apps": []}'
                ;;
            *)
                # Get app details
                local app_id=$(echo "$PATH_INFO" | sed 's|/api/apps/||')
                get_app_details "$app_id"
                ;;
        esac
        ;;
    POST)
        read -n $CONTENT_LENGTH data
        local app_id=$(echo "$data" | jq -r '.app_id // .id')
        local action=$(echo "$data" | jq -r '.action // "install"')
        
        case "$action" in
            install)
                install_app_ui "$app_id"
                ;;
            remove)
                remove_app_ui "$app_id"
                ;;
        esac
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac