#!/bin/sh
# ClawUI Packages API
# APK package management

# List packages
list_packages() {
    local filter="${1:-installed}"
    
    case "$filter" in
        installed)
            apk info -vv 2>/dev/null | while read pkg ver desc; do
                echo "{\"name\": \"$pkg\", \"version\": \"$ver\", \"description\": \"${desc:-}\"},"
            done | sed '$ s/,$//'
            ;;
        available)
            apk update 2>/dev/null
            apk search -v 2>/dev/null | head -100 | while read pkg ver; do
                echo "{\"name\": \"${pkg%-*}\", \"version\": \"$ver\"},"
            done | sed '$ s/,$//'
            ;;
        upgrades)
            apk upgrade -s 2>/dev/null | grep '^Upgrading' | while read _ pkg _ ver; do
                echo "{\"name\": \"$pkg\", \"new_version\": \"$ver\"},"
            done | sed '$ s/,$//'
            ;;
    esac
}

# Get package details
get_package_details() {
    local pkg="$1"
    local info=$(apk info -a "$pkg" 2>/dev/null)
    
    cat << EOF
{
    "name": "$pkg",
    "version": "$(apk info -v "$pkg" 2>/dev/null | head -1 | awk '{print $2}')",
    "description": "$(echo "$info" | grep description | head -1 | cut -d: -f2-)",
    "size": "$(echo "$info" | grep size | head -1 | cut -d: -f2-)",
    "installed": $(apk info -e "$pkg" 2>/dev/null && echo 'true' || echo 'false'),
    "depends": [$(apk info -R "$pkg" 2>/dev/null | tail -n +2 | head -10 | awk '{printf "\"%s\",", $1}' | sed 's/,$//')]
}
EOF
}

# Install package
install_package() {
    read -n $CONTENT_LENGTH data
    local pkg=$(echo "$data" | grep -o '"package":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$pkg" ]; then
        local output=$(apk add "$pkg" 2>&1)
        if [ $? -eq 0 ]; then
            echo "{\"success\": true, \"message\": \"Package $pkg installed\"}"
        else
            echo "{\"success\": false, \"message\": \"$output\"}"
        fi
    else
        echo '{"success": false, "message": "No package specified"}'
    fi
}

# Remove package
remove_package() {
    read -n $CONTENT_LENGTH data
    local pkg=$(echo "$data" | grep -o '"package":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$pkg" ]; then
        local output=$(apk del "$pkg" 2>&1)
        if [ $? -eq 0 ]; then
            echo "{\"success\": true, \"message\": \"Package $pkg removed\"}"
        else
            echo "{\"success\": false, \"message\": \"$output\"}"
        fi
    else
        echo '{"success": false, "message": "No package specified"}'
    fi
}

# Update repositories
update_repos() {
    local output=$(apk update 2>&1)
    echo "{\"success\": true, \"message\": \"Repositories updated\"}"
}

# Upgrade packages
upgrade_packages() {
    local output=$(apk upgrade 2>&1)
    echo "{\"success\": true, \"message\": \"Packages upgraded\"}"
}

# Route request
case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/packages/available)
                echo "["
                list_packages available
                echo "]"
                ;;
            /api/packages/upgrades)
                echo "["
                list_packages upgrades
                echo "]"
                ;;
            /api/packages/*)
                local pkg=$(echo "$PATH_INFO" | sed 's|/api/packages/||')
                get_package_details "$pkg"
                ;;
            *)
                echo "["
                list_packages installed
                echo "]"
                ;;
        esac
        ;;
    POST)
        case "$PATH_INFO" in
            /api/packages/install)
                install_package
                ;;
            /api/packages/remove)
                remove_package
                ;;
            /api/packages/update)
                update_repos
                ;;
            /api/packages/upgrade)
                upgrade_packages
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