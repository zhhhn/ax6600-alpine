#!/bin/sh
# ClawUI App Post-Install Hook
# Automatically registers app in ClawUI

APPS_DIR="/usr/share/clawui/apps"
REGISTRY="$APPS_DIR/registry.json"
MANIFEST="$APPS_DIR/$pkgname/manifest.json"

# Register app
register_app() {
    if [ -f "$MANIFEST" ]; then
        # Get app ID from manifest
        local app_id=$(jq -r '.id' "$MANIFEST")
        local app_name=$(jq -r '.name' "$MANIFEST")
        local app_icon=$(jq -r '.icon' "$MANIFEST")
        local app_category=$(jq -r '.category' "$MANIFEST")
        
        # Add to registry
        if [ -f "$REGISTRY" ]; then
            local tmp=$(mktemp)
            jq ".apps += [{
                \"id\": \"$app_id\",
                \"name\": \"$app_name\",
                \"icon\": \"$app_icon\",
                \"category\": \"$app_category\",
                \"path\": \"$APPS_DIR/$pkgname\"
            }]" "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
        fi
        
        echo "Registered ClawUI app: $app_name"
    fi
}

# Unregister app
unregister_app() {
    if [ -f "$MANIFEST" ]; then
        local app_id=$(jq -r '.id' "$MANIFEST")
        
        if [ -f "$REGISTRY" ]; then
            local tmp=$(mktemp)
            jq ".apps = [.apps[] | select(.id != \"$app_id\")]" "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
        fi
        
        echo "Unregistered ClawUI app: $app_id"
    fi
}

# Run
case "$1" in
    post-install)
        register_app
        ;;
    post-deinstall)
        unregister_app
        ;;
esac