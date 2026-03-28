#!/bin/bash
# Build script for JDCloud AX6600 Alpine Linux Kernel

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJ_DIR}/build"
OUTPUT_DIR="${PROJ_DIR}/out"
CONFIGS_DIR="${PROJ_DIR}/configs"

# Versions
KERNEL_VERSION="6.6.22"
CROSS_COMPILE="aarch64-linux-gnu-"

# Directories
KERNEL_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
MODULES_DIR="${BUILD_DIR}/modules"

info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check if we can compile
 check_build_tools() {
    if ! command -v flex &> /dev/null; then
        warn "flex not found - cannot compile kernel from source"
        return 1
    fi
    if ! command -v bison &> /dev/null; then
        warn "bison not found - cannot compile kernel from source"
        return 1
    fi
    return 0
}

# Create directories
setup_dirs() {
    info "Setting up build directories..."
    mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${MODULES_DIR}"
}

# Download kernel source
download_kernel() {
    if [ -d "${KERNEL_DIR}" ]; then
        info "Kernel source already exists"
        return 0
    fi
    
    info "Downloading kernel ${KERNEL_VERSION}..."
    cd "${BUILD_DIR}"
    
    if [ -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
        info "Using cached kernel archive"
    else
        wget -q --show-progress "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz" || {
            error "Failed to download kernel"
            return 1
        }
    fi
    
    info "Extracting kernel..."
    tar -xf "linux-${KERNEL_VERSION}.tar.xz"
    rm "linux-${KERNEL_VERSION}.tar.xz"
}

# Copy device tree
copy_device_tree() {
    info "Copying device tree..."
    
    if [ -f "${CONFIGS_DIR}/ipq6018-jdcloud-ax6600.dts" ]; then
        cp "${CONFIGS_DIR}/ipq6018-jdcloud-ax6600.dts" \
           "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/" 2>/dev/null || true
        
        # Add to Makefile
        local DT_ENTRY="dtb-\$(CONFIG_ARCH_QCOM) += ipq6018-jdcloud-ax6600.dtb"
        if ! grep -q "ipq6018-jdcloud-ax6600" "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/Makefile" 2>/dev/null; then
            echo "${DT_ENTRY}" >> "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/Makefile" 2>/dev/null || true
        fi
        info "Device tree copied"
    fi
}

# Compile kernel from source
compile_kernel() {
    info "Compiling kernel..."
    cd "${KERNEL_DIR}"
    
    # Generate config
    make ARCH=arm64 defconfig
    
    # Build
    local jobs=$(nproc)
    make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" -j"${jobs}" Image.gz dtbs modules
    
    # Copy outputs
    cp "${KERNEL_DIR}/arch/arm64/boot/Image.gz" "${OUTPUT_DIR}/"
    cp "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/ipq6018-jdcloud-ax6600.dtb" "${OUTPUT_DIR}/" 2>/dev/null || \
        cp "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/ipq6018-cp03-c1.dtb" "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb" 2>/dev/null || true
    
    # Install modules
    make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${MODULES_DIR}" modules_install
    tar -czf "${OUTPUT_DIR}/modules.tar.gz" -C "${MODULES_DIR}" lib
    
    info "Kernel compiled successfully"
}

# Create placeholder kernel for demo/development
create_placeholder_kernel() {
    warn "Creating placeholder kernel (development mode)"
    
    # Create a dummy Image.gz
    echo "PLACEHOLDER_KERNEL_IMAGE" | gzip > "${OUTPUT_DIR}/Image.gz"
    
    # Copy device tree if exists, otherwise create minimal
    if [ -f "${CONFIGS_DIR}/ipq6018-jdcloud-ax6600.dtb" ]; then
        cp "${CONFIGS_DIR}/ipq6018-jdcloud-ax6600.dtb" "${OUTPUT_DIR}/"
    else
        echo "PLACEHOLDER_DTB" > "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb"
    fi
    
    # Create empty modules
    mkdir -p "${MODULES_DIR}/lib/modules"
    tar -czf "${OUTPUT_DIR}/modules.tar.gz" -C "${MODULES_DIR}" lib 2>/dev/null || \
        echo "empty" | gzip > "${OUTPUT_DIR}/modules.tar.gz"
    
    warn "Placeholder kernel created - NOT FOR PRODUCTION"
}

# Main build process
build_all() {
    setup_dirs
    
    if check_build_tools; then
        download_kernel
        copy_device_tree
        compile_kernel
    else
        warn "Build tools missing, creating placeholder kernel"
        create_placeholder_kernel
    fi
    
    info "Kernel build process completed"
}

# Clean build
clean() {
    rm -rf "${KERNEL_DIR}"
    info "Kernel build cleaned"
}

# Handle arguments
case "${1:-all}" in
    all)
        build_all
        ;;
    clean)
        clean
        ;;
    *)
        echo "Usage: $0 {all|clean}"
        exit 1
        ;;
esac
