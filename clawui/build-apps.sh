# ClawUI 应用构建脚本
# 构建所有或指定的应用

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"
OUTPUT_DIR="$SCRIPT_DIR/out"
ROOTFS_DIR="$SCRIPT_DIR/rootfs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Build a single app
build_app() {
    local app_name="$1"
    local app_dir="$APPS_DIR/$app_name"
    
    if [ ! -d "$app_dir" ]; then
        log_error "App '$app_name' not found in $APPS_DIR"
        return 1
    fi
    
    log_info "Building app: $app_name"
    
    # Check required files
    if [ ! -f "$app_dir/manifest.json" ]; then
        log_error "manifest.json not found for $app_name"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Parse manifest
    local app_id=$(jq -r '.id' "$app_dir/manifest.json")
    local app_version=$(jq -r '.version' "$app_dir/manifest.json")
    local app_name_display=$(jq -r '.name' "$app_dir/manifest.json")
    
    log_info "  ID: $app_id"
    log_info "  Version: $app_version"
    log_info "  Name: $app_name_display"
    
    # Create temp build directory
    local build_dir=$(mktemp -d)
    trap "rm -rf $build_dir" EXIT
    
    # Copy app files
    cp -r "$app_dir"/* "$build_dir/"
    
    # Build APKBUILD if not exists
    # Determine package name - remove duplicate prefix if present
    local pkg_name="$app_id"
    case "$pkg_name" in
        clawui-app-*) ;;
        *) pkg_name="clawui-app-$pkg_name" ;;
    esac
    
    if [ ! -f "$build_dir/APKBUILD" ]; then
        cat > "$build_dir/APKBUILD" << EOF
# ClawUI $app_name_display App
pkgname=$pkg_name
pkgver=$app_version
pkgrel=1
pkgdesc="ClawUI $app_name_display 应用"
url="https://github.com/clawui/$pkg_name"
arch="noarch"
license="MIT"
depends="clawui"
source=""

package() {
    mkdir -p "\$pkgdir"/usr/share/clawui/apps/$app_id
    cp -r "\$srcdir"/* "\$pkgdir"/usr/share/clawui/apps/$app_id/
}
EOF
    fi
    
    # Create tarball - use app_id directly as it may already contain prefix
    local tarball_name="$app_id"
    local tarball="$OUTPUT_DIR/$tarball_name-$app_version.tar.gz"
    tar -czf "$tarball" -C "$build_dir" .
    
    log_info "  Built: $tarball"
    
    # Install to rootfs for development
    local install_dir="$ROOTFS_DIR/usr/share/clawui/apps/$app_id"
    mkdir -p "$install_dir"
    
    # Copy API
    if [ -d "$app_dir/api" ]; then
        mkdir -p "$ROOTFS_DIR/usr/share/clawui/api"
        cp -r "$app_dir/api"/* "$ROOTFS_DIR/usr/share/clawui/api/"
        chmod +x "$ROOTFS_DIR/usr/share/clawui/api"/*.sh
    fi
    
    # Copy manifest
    cp "$app_dir/manifest.json" "$install_dir/"
    
    # Copy www if exists
    if [ -d "$app_dir/www" ]; then
        cp -r "$app_dir/www" "$install_dir/"
    fi
    
    log_info "  Installed to: $install_dir"
    
    return 0
}

# List available apps
list_apps() {
    echo "Available apps:"
    echo ""
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/manifest.json" ]; then
            local name=$(basename "$app_dir")
            local display=$(jq -r '.name' "$app_dir/manifest.json")
            local version=$(jq -r '.version' "$app_dir/manifest.json")
            local category=$(jq -r '.category' "$app_dir/manifest.json")
            printf "  %-15s %-20s v%-8s [%s]\n" "$name" "$display" "$version" "$category"
        fi
    done
}

# Main
case "${1:-}" in
    all)
        log_info "Building all apps..."
        for app_dir in "$APPS_DIR"/*; do
            if [ -d "$app_dir" ] && [ -f "$app_dir/manifest.json" ]; then
                build_app "$(basename "$app_dir")" || true
            fi
        done
        log_info "Done!"
        ;;
    list)
        list_apps
        ;;
    "")
        echo "Usage: $0 <app_name|all|list>"
        echo ""
        list_apps
        ;;
    *)
        build_app "$1"
        ;;
esac