#!/bin/bash
# Simple APK package builder
# Creates Alpine .apk packages without abuild dependency
# Requires bash (not sh) for process substitution

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPS_DIR="${PROJ_DIR}/clawui/apps"
BUILD_DIR="${PROJ_DIR}/build/apk-simple"
OUTPUT_DIR="${PROJ_DIR}/out/packages"

info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Extract package info from APKBUILD
parse_apkbuild() {
    local apkbuild="$1"
    
    # Extract variables using grep and sed
    pkgname=$(grep '^pkgname=' "$apkbuild" | cut -d= -f2 | tr -d ' "'"'"'')
    pkgver=$(grep '^pkgver=' "$apkbuild" | cut -d= -f2 | tr -d ' "'"'"'')
    pkgrel=$(grep '^pkgrel=' "$apkbuild" | cut -d= -f2 | tr -d ' "'"'"'')
    pkgdesc=$(grep '^pkgdesc=' "$apkbuild" | cut -d= -f2 | tr -d ' "'"'"'')
    arch=$(grep '^arch=' "$apkbuild" | cut -d= -f2 | tr -d ' "'"'"'')
    license=$(grep '^license=' "$apkbuild" | cut -d= -f2 | tr -d ' "'"'"'')
    depends=$(grep '^depends=' "$apkbuild" | cut -d= -f2 | tr -d ' "'"'"'')
    
    # Default values
    pkgrel=${pkgrel:-0}
    arch=${arch:-noarch}
}

# Create .PKGINFO file
create_pkginfo() {
    local pkgdir="$1"
    local output="$2"
    
    cat > "${pkgdir}/.PKGINFO" << EOF
pkgname = ${pkgname}
pkgver = ${pkgver}-r${pkgrel}
arch = ${arch}
license = ${license}
origin = ClawUI
description = ${pkgdesc}
EOF

    if [ -n "$depends" ]; then
        echo "depend = ${depends}" >> "${pkgdir}/.PKGINFO"
    fi
}

# Create .INSTALL file (optional post-install script)
create_install() {
    local app_dir="$1"
    local pkgdir="$2"
    
    if [ -f "${app_dir}/post-install.sh" ]; then
        cp "${app_dir}/post-install.sh" "${pkgdir}/.INSTALL"
    fi
}

# Build APK package
build_apk() {
    local app_name="$1"
    local app_dir="${APPS_DIR}/${app_name}"
    
    if [ ! -f "${app_dir}/APKBUILD" ]; then
        error "APKBUILD not found for ${app_name}"
        return 1
    fi
    
    info "Building APK: ${app_name}..."
    
    # Parse APKBUILD
    parse_apkbuild "${app_dir}/APKBUILD"
    
    if [ -z "$pkgname" ]; then
        error "Failed to parse APKBUILD for ${app_name}"
        return 1
    fi
    
    info "  Package: ${pkgname}-${pkgver}-r${pkgrel} (${arch})"
    
    # Create package directory structure
    local pkg_dir="${BUILD_DIR}/${app_name}/pkg"
    rm -rf "${pkg_dir}"
    mkdir -p "${pkg_dir}"
    
    # Create .PKGINFO
    create_pkginfo "${pkg_dir}" "${app_name}"
    
    # Create .INSTALL if exists
    create_install "${app_dir}" "${pkg_dir}"
    
    # Run package function from APKBUILD
    # We need to simulate the build environment
    export srcdir="${app_dir}"
    export pkgdir="${pkg_dir}"
    
    # Source APKBUILD and run package()
    (
        cd "${app_dir}"
        source APKBUILD
        package 2>/dev/null || true
    )
    
    # Create tarball
    local apk_file="${OUTPUT_DIR}/${pkgname}-${pkgver}-r${pkgrel}_${arch}.apk"
    
    cd "${pkg_dir}"
    
    # Create the APK (which is a tar.gz with specific format)
    tar -czf "${apk_file}" .
    
    info "  ✓ Created: ${apk_file}"
    
    # Show size
    local size=$(du -h "${apk_file}" | cut -f1)
    info "  Size: ${size}"
}

# Build all packages
build_all() {
    info "Building all APK packages..."
    
    mkdir -p "${OUTPUT_DIR}"
    
    local apps=(
        "kms"
        "nps"
        "aria2"
        "wireguard"
        "pppoe"
        "frp"
    )
    
    local success=0
    local failed=0
    
    for app in "${apps[@]}"; do
        if [ -d "${APPS_DIR}/${app}" ]; then
            if build_apk "$app"; then
                ((success++))
            else
                ((failed++))
            fi
        fi
    done
    
    info ""
    info "Build complete: ${success} succeeded, ${failed} failed"
    
    if [ $success -gt 0 ]; then
        info ""
        info "Packages available in: ${OUTPUT_DIR}"
        ls -lh "${OUTPUT_DIR}"/*.apk 2>/dev/null || true
    fi
}

# Install a package (copy to rootfs)
install_package() {
    local apk_file="$1"
    local rootfs="$2"
    
    if [ ! -f "$apk_file" ]; then
        error "Package not found: $apk_file"
        return 1
    fi
    
    info "Installing ${apk_file} to ${rootfs}..."
    
    # Extract package to rootfs
    tar -xzf "$apk_file" -C "$rootfs"
    
    # Run post-install if exists
    if [ -f "${rootfs}/.INSTALL" ]; then
        info "Running post-install script..."
        # Note: This would need chroot to run properly
        info "Post-install script found (requires chroot to execute)"
    fi
    
    info "Package installed"
}

# Clean build artifacts
clean() {
    info "Cleaning build artifacts..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${OUTPUT_DIR}"
    info "Clean complete"
}

# Show usage
usage() {
    echo "Usage: $0 [command] [package]"
    echo ""
    echo "Commands:"
    echo "  all          Build all packages (default)"
    echo "  build <pkg>  Build specific package"
    echo "  install <apk> <rootfs>  Install APK to rootfs"
    echo "  clean        Clean build artifacts"
    echo "  help         Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 all"
    echo "  $0 build kms"
    echo "  $0 build nps"
    echo "  $0 build aria2"
    echo "  $0 install out/packages/kms-server-1.0.0-r0_noarch.apk build/alpine-rootfs"
}

# Main
main() {
    case "${1:-all}" in
        all)
            build_all
            ;;
        build)
            if [ -z "$2" ]; then
                error "Please specify package name"
                usage
                exit 1
            fi
            mkdir -p "${OUTPUT_DIR}"
            build_apk "$2"
            ;;
        install)
            if [ -z "$2" ] || [ -z "$3" ]; then
                error "Please specify APK file and rootfs path"
                usage
                exit 1
            fi
            install_package "$2" "$3"
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
