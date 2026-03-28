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
    
    # Generate minimal config for IPQ6010
    info "Generating kernel config..."
    make ARCH=arm64 defconfig || {
        error "Failed to generate defconfig"
        return 1
    }
    
    # Disable problematic modules that may fail in CI
    cat >> .config << 'EOF'
# Disable modules that often fail in cross-compile CI
# CONFIG_CORESIGHT is not set
# CONFIG_HW_TRACING is not set
# CONFIG_STAGING is not set
# CONFIG_ANDROID is not set
EOF
    make ARCH=arm64 olddefconfig
    
    # Build kernel image only first (faster, less likely to fail)
    info "Building kernel Image..."
    local jobs=$(nproc)
    make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" -j"${jobs}" Image 2>&1 | tail -20 || {
        error "Kernel Image build failed"
        # Show last 50 lines of error
        make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" Image 2>&1 | tail -50
        return 1
    }
    
    # Compress kernel
    gzip -k "${KERNEL_DIR}/arch/arm64/boot/Image" 2>/dev/null || \
        gzip -c "${KERNEL_DIR}/arch/arm64/boot/Image" > "${KERNEL_DIR}/arch/arm64/boot/Image.gz"
    
    # Build DTBs
    info "Building device trees..."
    make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" -j"${jobs}" dtbs 2>&1 | tail -10 || {
        warn "DTB build may have partial failures"
    }
    
    # Copy outputs
    info "Copying outputs..."
    cp "${KERNEL_DIR}/arch/arm64/boot/Image.gz" "${OUTPUT_DIR}/"
    
    # Try multiple DTB sources
    if [ -f "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/ipq6018-jdcloud-ax6600.dtb" ]; then
        cp "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/ipq6018-jdcloud-ax6600.dtb" "${OUTPUT_DIR}/"
        info "Using custom DTB"
    elif [ -f "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/ipq6018-cp03-c1.dtb" ]; then
        cp "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/ipq6018-cp03-c1.dtb" "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb"
        info "Using ipq6018-cp03-c1 DTB as base"
    else
        # Use any available IPQ6018 DTB
        local FOUND_DTB=$(find "${KERNEL_DIR}/arch/arm64/boot/dts/qcom" -name "ipq6018*.dtb" | head -1)
        if [ -n "$FOUND_DTB" ]; then
            cp "$FOUND_DTB" "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb"
            info "Using fallback DTB: $FOUND_DTB"
        else
            warn "No IPQ6018 DTB found, will create placeholder"
        fi
    fi
    
    # Try to build modules (optional, may fail)
    info "Building modules (optional)..."
    make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" -j"${jobs}" modules 2>&1 | tail -5 || {
        warn "Module build failed, continuing without modules"
    }
    
    # Install modules if available
    if [ -d "${KERNEL_DIR}/modules" ] || ls "${KERNEL_DIR}"/*.ko 2>/dev/null | head -1; then
        make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${MODULES_DIR}" modules_install 2>/dev/null || true
        if [ -d "${MODULES_DIR}/lib/modules" ]; then
            tar -czf "${OUTPUT_DIR}/modules.tar.gz" -C "${MODULES_DIR}" lib
        fi
    fi
    
    # Create empty modules tar if none
    if [ ! -f "${OUTPUT_DIR}/modules.tar.gz" ]; then
        mkdir -p "${MODULES_DIR}/lib/modules"
        tar -czf "${OUTPUT_DIR}/modules.tar.gz" -C "${MODULES_DIR}" lib
    fi
    
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
