#!/bin/sh
# Build ClawUI App Packages
# Creates .apk packages for ClawUI apps

APPS_DIR="apps"
OUTPUT_DIR="packages"

build_app() {
    local app_dir="$1"
    local app_name=$(basename "$app_dir")
    
    if [ ! -f "$app_dir/APKBUILD" ]; then
        echo "Skipping $app_name: No APKBUILD"
        return
    fi
    
    echo "Building $app_name..."
    
    # Create package directory
    mkdir -p "$OUTPUT_DIR"
    
    # Build using abuild (Alpine's build tool)
    cd "$app_dir"
    
    # Create temp package structure
    local pkg_dir="/tmp/clawui-$app_name"
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/usr/share/clawui/apps/$app_name"
    
    # Copy files
    cp -r api i18n manifest.json 2>/dev/null
    cp -r www/* "$pkg_dir/usr/share/clawui/apps/$app_name/" 2>/dev/null || true
    cp -r api "$pkg_dir/usr/share/clawui/apps/$app_name/" 2>/dev/null || true
    cp -r i18n "$pkg_dir/usr/share/clawui/apps/$app_name/" 2>/dev/null || true
    cp manifest.json "$pkg_dir/usr/share/clawui/apps/$app_name/" 2>/dev/null || true
    
    # Create control file
    mkdir -p "$pkg_dir/var/lib/apk"
    
    # Package info
    cat > "$pkg_dir/.PKGINFO" << EOF
pkgname = clawui-app-$app_name
pkgver = 1.0.0
pkgdesc = ClawUI app for $app_name
url = https://github.com/openclaw/clawui
builddate = $(date +%s)
size = $(du -sk "$pkg_dir" | cut -f1)
arch = noarch
license = MIT
depend = clawutils
EOF
    
    # Create tarball
    cd "$pkg_dir"
    tar -czf "$OLDPWD/$OUTPUT_DIR/clawui-app-$app_name-1.0.0.apk" *
    
    echo "Created: $OUTPUT_DIR/clawui-app-$app_name-1.0.0.apk"
    
    # Cleanup
    rm -rf "$pkg_dir"
    cd "$OLDPWD"
}

# Build all apps
build_all() {
    for app in "$APPS_DIR"/*/; do
        [ -d "$app" ] && build_app "$app"
    done
}

# Main
mkdir -p "$OUTPUT_DIR"

if [ -n "$1" ]; then
    build_app "$APPS_DIR/$1"
else
    build_all
fi

echo ""
echo "Packages created in $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR"/*.apk 2>/dev/null || echo "No packages created"