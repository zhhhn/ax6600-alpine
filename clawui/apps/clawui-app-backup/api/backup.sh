#!/bin/sh
# ClawUI Backup & Restore App API
# System configuration backup and restore

CONF_DIR="/etc/clawui/backup"
BACKUP_DIR="/var/lib/clawui/backups"
SETTINGS_CONF="$CONF_DIR/settings.json"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Initialize
init_config() {
    mkdir -p "$CONF_DIR"
    mkdir -p "$BACKUP_DIR"
    [ ! -f "$SETTINGS_CONF" ] && echo '{"auto_backup": false, "backup_count": 5, "include_packages": true}' > "$SETTINGS_CONF"
}

# Get backup status
get_status() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local backups=$(list_backups_raw)
    local backup_count=$(echo "$backups" | jq 'length')
    local last_backup=$(echo "$backups" | jq -r '.[0].created // ""')
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
    
    cat << EOF
{
    "backup_dir": "$BACKUP_DIR",
    "total_size": "${total_size:-0}",
    "backup_count": $backup_count,
    "last_backup": "$last_backup",
    "settings": $settings
}
EOF
}

# List backups
list_backups() {
    init_config
    list_backups_raw
}

list_backups_raw() {
    local result="["
    local first=1
    
    for backup in "$BACKUP_DIR"/*.tar.gz; do
        [ -f "$backup" ] || continue
        
        local name=$(basename "$backup" .tar.gz)
        local size=$(stat -c%s "$backup" 2>/dev/null || echo 0)
        local created=$(stat -c%y "$backup" 2>/dev/null | cut -d. -f1)
        local type=$(echo "$name" | grep -o 'manual\|auto\|scheduled' || echo "manual")
        
        [ "$first" = "0" ] && result="$result,"
        first=0
        
        result="$result{\"name\": \"$name\", \"file\": \"$backup\", \"size\": $size, \"created\": \"$created\", \"type\": \"$type\"}"
    done
    
    result="$result]"
    
    # Sort by created date descending
    echo "$result" | jq 'sort_by(.created) | reverse'
}

# Create backup
create_backup() {
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local name=$(echo "$data" | jq -r '.name // "manual"')
    local type=$(echo "$data" | jq -r '.type // "manual"')
    local include=$(echo "$data" | jq -r '.include // []')
    
    # Generate backup name
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${type}-${name}-${timestamp}"
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Backup directories
    local backup_items=""
    
    # Network config
    if [ -d /etc/network ]; then
        cp -r /etc/network "$temp_dir/"
        backup_items="$backup_items /etc/network"
    fi
    
    # Network interfaces
    if [ -f /etc/network/interfaces ]; then
        cp /etc/network/interfaces "$temp_dir/" 2>/dev/null
    fi
    
    # Hostapd
    if [ -d /etc/hostapd ]; then
        cp -r /etc/hostapd "$temp_dir/" 2>/dev/null
        backup_items="$backup_items /etc/hostapd"
    fi
    
    # Dnsmasq
    if [ -d /etc/dnsmasq.d ]; then
        mkdir -p "$temp_dir/dnsmasq.d"
        cp -r /etc/dnsmasq.d/* "$temp_dir/dnsmasq.d/" 2>/dev/null
        backup_items="$backup_items /etc/dnsmasq.d"
    fi
    
    # Firewall (nftables)
    if [ -f /etc/nftables.conf ]; then
        cp /etc/nftables.conf "$temp_dir/" 2>/dev/null
        backup_items="$backup_items /etc/nftables.conf"
    fi
    
    # ClawUI config
    if [ -d /etc/clawui ]; then
        cp -r /etc/clawui "$temp_dir/" 2>/dev/null
        backup_items="$backup_items /etc/clawui"
    fi
    
    # WireGuard
    if [ -d /etc/wireguard ]; then
        cp -r /etc/wireguard "$temp_dir/" 2>/dev/null
        backup_items="$backup_items /etc/wireguard"
    fi
    
    # PPP/PPPoE
    if [ -d /etc/ppp ]; then
        mkdir -p "$temp_dir/ppp"
        cp /etc/ppp/pap-secrets "$temp_dir/ppp/" 2>/dev/null
        cp /etc/ppp/chap-secrets "$temp_dir/ppp/" 2>/dev/null
        cp -r /etc/ppp/peers "$temp_dir/ppp/" 2>/dev/null
        backup_items="$backup_items /etc/ppp"
    fi
    
    # FRP
    if [ -d /etc/frp ]; then
        cp -r /etc/frp "$temp_dir/" 2>/dev/null
        backup_items="$backup_items /etc/frp"
    fi
    
    # DDNS
    if [ -d /etc/ddns ]; then
        cp -r /etc/ddns "$temp_dir/" 2>/dev/null
        backup_items="$backup_items /etc/ddns"
    fi
    
    # System settings
    cp /etc/hostname "$temp_dir/" 2>/dev/null
    cp /etc/hosts "$temp_dir/" 2>/dev/null
    cp /etc/resolv.conf "$temp_dir/" 2>/dev/null
    cp -r /etc/localtime "$temp_dir/" 2>/dev/null
    
    # Installed packages list
    if [ "$(echo "$data" | jq -r '.include_packages')" = "true" ]; then
        apk info > "$temp_dir/installed_packages.txt" 2>/dev/null
    fi
    
    # Create manifest
    cat > "$temp_dir/manifest.json" << EOF
{
    "version": "1.0",
    "created": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "alpine_version": "$(cat /etc/alpine-release 2>/dev/null)",
    "type": "$type",
    "name": "$name",
    "items": "$backup_items"
}
EOF
    
    # Create tarball
    tar -czf "$backup_file" -C "$temp_dir" .
    
    local size=$(stat -c%s "$backup_file" 2>/dev/null)
    
    # Cleanup old backups
    cleanup_old_backups
    
    echo "{\"success\": true, \"message\": \"备份已创建\", \"name\": \"$backup_name\", \"file\": \"$backup_file\", \"size\": $size}"
}

# Restore backup
restore_backup() {
    local name="$1"
    read -n $CONTENT_LENGTH data
    
    init_config
    
    local backup_file="$BACKUP_DIR/${name}.tar.gz"
    
    if [ ! -f "$backup_file" ]; then
        echo '{"success": false, "message": "备份文件不存在"}'
        return 1
    fi
    
    local restore_items=$(echo "$data" | jq -r '.items // []')
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Extract backup
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Check manifest
    if [ -f "$temp_dir/manifest.json" ]; then
        local manifest=$(cat "$temp_dir/manifest.json")
    fi
    
    # Restore files
    local restored="[]"
    
    # Restore network config
    if [ -d "$temp_dir/network" ] && echo "$restore_items" | jq -e 'index("network")' >/dev/null; then
        cp -r "$temp_dir/network"/* /etc/network/ 2>/dev/null
        restored=$(echo "$restored" | jq '. + ["network"]')
    fi
    
    # Restore hostapd
    if [ -d "$temp_dir/hostapd" ] && echo "$restore_items" | jq -e 'index("wireless")' >/dev/null; then
        cp -r "$temp_dir/hostapd"/* /etc/hostapd/ 2>/dev/null
        restored=$(echo "$restored" | jq '. + ["wireless"]')
    fi
    
    # Restore dnsmasq
    if [ -d "$temp_dir/dnsmasq.d" ] && echo "$restore_items" | jq -e 'index("dhcp")' >/dev/null; then
        cp -r "$temp_dir/dnsmasq.d"/* /etc/dnsmasq.d/ 2>/dev/null
        restored=$(echo "$restored" | jq '. + ["dhcp"]')
    fi
    
    # Restore firewall
    if [ -f "$temp_dir/nftables.conf" ] && echo "$restore_items" | jq -e 'index("firewall")' >/dev/null; then
        cp "$temp_dir/nftables.conf" /etc/nftables.conf 2>/dev/null
        restored=$(echo "$restored" | jq '. + ["firewall"]')
    fi
    
    # Restore ClawUI config
    if [ -d "$temp_dir/clawui" ] && echo "$restore_items" | jq -e 'index("clawui")' >/dev/null; then
        cp -r "$temp_dir/clawui"/* /etc/clawui/ 2>/dev/null
        restored=$(echo "$restored" | jq '. + ["clawui"]')
    fi
    
    # Restore WireGuard
    if [ -d "$temp_dir/wireguard" ] && echo "$restore_items" | jq -e 'index("wireguard")' >/dev/null; then
        cp -r "$temp_dir/wireguard"/* /etc/wireguard/ 2>/dev/null
        restored=$(echo "$restored" | jq '. + ["wireguard"]')
    fi
    
    # Restore PPP
    if [ -d "$temp_dir/ppp" ] && echo "$restore_items" | jq -e 'index("ppp")' >/dev/null; then
        cp -r "$temp_dir/ppp"/* /etc/ppp/ 2>/dev/null
        restored=$(echo "$restored" | jq '. + ["ppp"]')
    fi
    
    # Restore system
    if echo "$restore_items" | jq -e 'index("system")' >/dev/null; then
        [ -f "$temp_dir/hostname" ] && cp "$temp_dir/hostname" /etc/hostname
        [ -f "$temp_dir/hosts" ] && cp "$temp_dir/hosts" /etc/hosts
        restored=$(echo "$restored" | jq '. + ["system"]')
    fi
    
    echo "{\"success\": true, \"message\": \"配置已恢复，建议重启生效\", \"restored\": $restored}"
}

# Delete backup
delete_backup() {
    local name="$1"
    init_config
    
    local backup_file="$BACKUP_DIR/${name}.tar.gz"
    
    if [ -f "$backup_file" ]; then
        rm -f "$backup_file"
        echo '{"success": true, "message": "备份已删除"}'
    else
        echo '{"success": false, "message": "备份不存在"}'
    fi
}

# Download backup
download_backup() {
    local name="$1"
    local backup_file="$BACKUP_DIR/${name}.tar.gz"
    
    if [ -f "$backup_file" ]; then
        # Return file info for download
        echo "{\"file\": \"$backup_file\", \"name\": \"${name}.tar.gz\", \"size\": $(stat -c%s "$backup_file")}"
    else
        echo '{"error": "Backup not found"}'
    fi
}

# Upload backup
upload_backup() {
    init_config
    
    # This would handle file upload
    # For now, return placeholder
    echo '{"success": false, "message": "上传功能需要前端支持"}'
}

# Cleanup old backups
cleanup_old_backups() {
    init_config
    
    local settings=$(cat "$SETTINGS_CONF")
    local keep_count=$(echo "$settings" | jq -r '.backup_count // 5')
    
    # Count current backups
    local count=$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    
    # Delete oldest if exceeds limit
    if [ $count -gt $keep_count ]; then
        ls -t "$BACKUP_DIR"/*.tar.gz | tail -n +$((keep_count + 1)) | xargs rm -f
    fi
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
    
    local auto_backup=$(echo "$data" | jq -r '.auto_backup // empty')
    local backup_count=$(echo "$data" | jq -r '.backup_count // empty')
    local include_packages=$(echo "$data" | jq -r '.include_packages // empty')
    
    local updates="{}"
    [ -n "$auto_backup" ] && updates=$(echo "$updates" | jq ". + {\"auto_backup\": $auto_backup}")
    [ -n "$backup_count" ] && updates=$(echo "$updates" | jq ". + {\"backup_count\": $backup_count}")
    [ -n "$include_packages" ] && updates=$(echo "$updates" | jq ". + {\"include_packages\": $include_packages}")
    
    local updated=$(cat "$SETTINGS_CONF" | jq ". + $updates")
    echo "$updated" > "$SETTINGS_CONF"
    
    echo '{"success": true, "message": "设置已保存"}'
}

# Factory reset
factory_reset() {
    read -n $CONTENT_LENGTH data
    
    local confirm=$(echo "$data" | jq -r '.confirm // false')
    
    if [ "$confirm" != "true" ]; then
        echo '{"success": false, "message": "需要确认才能恢复出厂设置"}'
        return 1
    fi
    
    # Reset network
    cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto br-lan
iface br-lan inet static
    address 192.168.1.1
    netmask 255.255.255.0
    bridge-ports eth1 eth2 eth3 eth4
EOF
    
    # Reset firewall
    echo "" > /etc/nftables.conf
    
    # Reset hostname
    echo "OpenClaw" > /etc/hostname
    
    # Clear ClawUI config
    rm -rf /etc/clawui/*
    
    echo '{"success": true, "message": "已恢复出厂设置，请重启设备"}'
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/backup/list)
                list_backups
                ;;
            /api/apps/backup/settings)
                get_settings
                ;;
            /api/apps/backup/download/*)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/backup/download/||')
                download_backup "$name"
                ;;
            *)
                get_status
                ;;
        esac
        ;;
    POST)
        init_config
        case "$PATH_INFO" in
            /api/apps/backup/create)
                create_backup
                ;;
            /api/apps/backup/restore/*)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/backup/restore/||')
                restore_backup "$name"
                ;;
            /api/apps/backup/settings)
                update_settings
                ;;
            /api/apps/backup/upload)
                upload_backup
                ;;
            /api/apps/backup/factory-reset)
                factory_reset
                ;;
            *)
                echo '{"error": "Unknown action"}'
                ;;
        esac
        ;;
    DELETE)
        case "$PATH_INFO" in
            /api/apps/backup/*)
                local name=$(echo "$PATH_INFO" | sed 's|/api/apps/backup/||')
                delete_backup "$name"
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