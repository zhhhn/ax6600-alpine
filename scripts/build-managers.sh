#!/bin/bash
# Build APK packages for ClawUI Apps
# These are management interfaces for Alpine official packages

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPS_DIR="${PROJ_DIR}/clawui/apps"
BUILD_DIR="${PROJ_DIR}/build/apk-apps"
OUTPUT_DIR="${PROJ_DIR}/out/packages"

info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Build a single ClawUI app APK
build_app() {
    local app_name="$1"
    local app_dir="${APPS_DIR}/${app_name}"
    
    if [ ! -f "${app_dir}/APKBUILD" ]; then
        error "APKBUILD not found for ${app_name}"
        return 1
    fi
    
    info "Building ClawUI app: ${app_name}..."
    
    # Create package directory
    local pkg_dir="${BUILD_DIR}/${app_name}/pkg"
    rm -rf "${pkg_dir}"
    mkdir -p "${pkg_dir}"
    
    # Create .PKGINFO
    local pkgname=$(grep '^pkgname=' "${app_dir}/APKBUILD" | cut -d= -f2 | tr -d ' "'"'"'')
    local pkgver=$(grep '^pkgver=' "${app_dir}/APKBUILD" | cut -d= -f2 | tr -d ' "'"'"'')
    local pkgrel=$(grep '^pkgrel=' "${app_dir}/APKBUILD" | cut -d= -f2 | tr -d ' "'"'"'')
    local pkgdesc=$(grep '^pkgdesc=' "${app_dir}/APKBUILD" | cut -d= -f2 | tr -d ' "'"'"'')
    local arch=$(grep '^arch=' "${app_dir}/APKBUILD" | cut -d= -f2 | tr -d ' "'"'"'')
    
    cat > "${pkg_dir}/.PKGINFO" << EOF
pkgname = ${pkgname}
pkgver = ${pkgver}-r${pkgrel}
arch = ${arch}
license = MIT
origin = ClawUI
description = ${pkgdesc}
EOF
    
    # Copy files
    mkdir -p "${pkg_dir}/usr/share/clawui/apps/${app_name}"
    cp -r "${app_dir}"/www/* "${pkg_dir}/usr/share/clawui/apps/${app_name}/" 2>/dev/null || true
    cp "${app_dir}/manifest.json" "${pkg_dir}/usr/share/clawui/apps/${app_name}/" 2>/dev/null || true
    
    mkdir -p "${pkg_dir}/usr/share/clawui/apps/${app_name}/api"
    cp "${app_dir}/api/handler.sh" "${pkg_dir}/usr/share/clawui/apps/${app_name}/api/" 2>/dev/null || true
    chmod +x "${pkg_dir}/usr/share/clawui/apps/${app_name}/api/handler.sh"
    
    if [ -d "${app_dir}/i18n" ]; then
        mkdir -p "${pkg_dir}/usr/share/clawui/apps/${app_name}/i18n"
        cp -r "${app_dir}/i18n"/* "${pkg_dir}/usr/share/clawui/apps/${app_name}/i18n/" 2>/dev/null || true
    fi
    
    # Create APK
    local apk_file="${OUTPUT_DIR}/${pkgname}-${pkgver}-r${pkgrel}_${arch}.apk"
    cd "${pkg_dir}"
    tar -czf "${apk_file}" .
    
    info "  ✓ Created: ${apk_file}"
}

# Build all ClawUI apps
build_all() {
    info "Building all ClawUI app APKs..."
    mkdir -p "${OUTPUT_DIR}"
    
    local apps=(
        "clawui-app-aria2"
        "clawui-app-nps"
        "clawui-app-npc"
        "clawui-app-kms"
        "clawui-app-frp"
        "clawui-app-transmission"
        "clawui-app-adguard"
        "clawui-app-vsftpd"
        "clawui-app-samba"
    )
    
    for app in "${apps[@]}"; do
        if [ -d "${APPS_DIR}/${app}" ]; then
            build_app "$app" || true
        fi
    done
    
    info ""
    info "Build complete!"
    info "Packages in: ${OUTPUT_DIR}"
    ls -lh "${OUTPUT_DIR}"/*.apk 2>/dev/null || true
}

# Main
case "${1:-all}" in
    all) build_all ;;
    build) build_app "$2" ;;
    *) info "Usage: $0 [all|build <app>]"; exit 1 ;;
esac
