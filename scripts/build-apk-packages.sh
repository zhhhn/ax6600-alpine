#!/bin/bash
# Build APK packages for ClawUI applications
# Creates proper Alpine Linux .apk packages

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPS_DIR="${PROJ_DIR}/clawui/apps"
BUILD_DIR="${PROJ_DIR}/build/apk"
OUTPUT_DIR="${PROJ_DIR}/out/packages"

info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Setup build environment
setup_build_env() {
    info "Setting up APK build environment..."
    
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${OUTPUT_DIR}"
    
    # Check for abuild
    if ! command -v abuild &> /dev/null; then
        info "abuild not found. Installing build dependencies..."
        apk add --no-cache abuild devtools 2>/dev/null || {
            error "Failed to install abuild. Please run: apk add abuild devtools"
            exit 1
        }
    fi
    
    # Setup abuild user and keys
    if [ ! -f ~/.abuild/abuild.conf ]; then
        mkdir -p ~/.abuild
        echo "PACKAGER=\"ClawUI Builder <clawui@localhost>\"" > ~/.abuild/abuild.conf
    fi
    
    # Generate signing keys if needed
    if [ ! -f ~/.abuild/*.rsa.pub ]; then
        info "Generating package signing keys..."
        abuild-keygen -a -n 2>/dev/null || true
    fi
    
    info "Build environment ready"
}

# Build a single APK package
build_package() {
    local app_name="$1"
    local app_dir="${APPS_DIR}/${app_name}"
    
    if [ ! -f "${app_dir}/APKBUILD" ]; then
        error "APKBUILD not found for ${app_name}"
        return 1
    fi
    
    info "Building package: ${app_name}..."
    
    # Create build directory for this package
    local pkg_build_dir="${BUILD_DIR}/${app_name}"
    rm -rf "${pkg_build_dir}"
    mkdir -p "${pkg_build_dir}"
    
    # Copy APKBUILD and source files
    cp -r "${app_dir}"/* "${pkg_build_dir}/"
    
    # Build the package
    cd "${pkg_build_dir}"
    
    # Update checksums (if source files exist)
    if [ -n "$(ls -A . 2>/dev/null | grep -v APKBUILD)" ]; then
        abuild checksum 2>/dev/null || true
    fi
    
    # Build package (non-interactive)
    export USE_CCACHE=0
    abuild -r 2>&1 | tail -20
    
    # Copy built packages to output directory
    local apk_path="${BUILD_DIR}/${app_name}/packages/"
    if [ -d "${apk_path}" ]; then
        cp "${apk_path}"/*.apk "${OUTPUT_DIR}/" 2>/dev/null || true
        info "✓ Built: $(ls ${apk_path}/*.apk 2>/dev/null | head -1)"
    else
        error "Failed to build ${app_name}"
        return 1
    fi
}

# Build all packages
build_all() {
    info "Building all ClawUI application packages..."
    
    local apps=(
        "wireguard"
        "pppoe"
        "kms"
        "nps"
        "aria2"
        "frp"
        "multiwan"
        "adblock"
        "qos"
        "portforward"
        "ddns"
        "diag"
        "backup"
        "routes"
        "traffic"
    )
    
    local success=0
    local failed=0
    
    for app in "${apps[@]}"; do
        if [ -d "${APPS_DIR}/${app}" ] && [ -f "${APPS_DIR}/${app}/APKBUILD" ]; then
            if build_package "$app"; then
                ((success++))
            else
                ((failed++))
            fi
        else
            info "Skipping ${app} (no APKBUILD)"
        fi
    done
    
    info ""
    info "Build complete: ${success} succeeded, ${failed} failed"
}

# Create package repository
create_repo() {
    info "Creating package repository..."
    
    cd "${OUTPUT_DIR}"
    
    # Create index
    abuild-index -o . 2>/dev/null || {
        info "Creating simple package list..."
        ls -1 *.apk 2>/dev/null > APKINDEX.txt || true
    }
    
    info "Repository created in ${OUTPUT_DIR}"
    info ""
    info "Available packages:"
    ls -lh "${OUTPUT_DIR}"/*.apk 2>/dev/null || true
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
    echo "  repo         Create package repository"
    echo "  clean        Clean build artifacts"
    echo "  help         Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 all"
    echo "  $0 build kms"
    echo "  $0 build nps"
    echo "  $0 build aria2"
}

# Main
main() {
    case "${1:-all}" in
        all)
            setup_build_env
            build_all
            create_repo
            ;;
        build)
            if [ -z "$2" ]; then
                error "Please specify package name"
                usage
                exit 1
            fi
            setup_build_env
            build_package "$2"
            ;;
        repo)
            create_repo
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
