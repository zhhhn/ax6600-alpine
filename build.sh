#!/bin/bash
# Main build script for JDCloud AX6600 Alpine Linux

set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJ_DIR}/build"
OUTPUT_DIR="${PROJ_DIR}/out"

echo "========================================"
echo "JDCloud AX6600 Alpine Linux Build System"
echo "========================================"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Parse arguments
BUILD_APKS="${BUILD_APKS:-1}"
INSTALL_APKS="${INSTALL_APKS:-1}"

# Check if we should build APK packages
if [ "${BUILD_APKS}" = "1" ]; then
    echo "[1/4] Building APK packages..."
    if [ -x "${PROJ_DIR}/scripts/build-apk-simple.sh" ]; then
        bash "${PROJ_DIR}/scripts/build-apk-simple.sh" all || {
            echo "WARN: APK build failed, continuing without packages"
        }
    else
        echo "SKIP: APK build script not found"
    fi
    echo ""
fi

# Check if we should skip kernel build
if [ "${SKIP_KERNEL:-}" != "1" ]; then
    echo "[2/4] Building kernel..."
    bash "${PROJ_DIR}/scripts/build-kernel.sh" all || { 
        echo "ERROR: Kernel build failed"
        exit 1
    }
    echo ""
fi

# Check if we should skip rootfs build
if [ "${SKIP_ROOTFS:-}" != "1" ]; then
    echo "[3/4] Building rootfs..."
    bash "${PROJ_DIR}/scripts/build-rootfs.sh" || { 
        echo "ERROR: Rootfs build failed"
        exit 1
    }
    
    # Install APK packages to rootfs if available
    if [ "${INSTALL_APKS}" = "1" ] && [ -d "${OUTPUT_DIR}/packages" ]; then
        echo ""
        echo "Installing APK packages to rootfs..."
        for apk in "${OUTPUT_DIR}/packages"/*.apk; do
            if [ -f "$apk" ]; then
                echo "  Installing: $(basename $apk)"
                tar -xzf "$apk" -C "${BUILD_DIR}/alpine-rootfs/" || true
            fi
        done
        echo "APK packages installed"
    fi
    echo ""
fi

# Package firmware
echo "[4/4] Packaging firmware..."
bash "${PROJ_DIR}/scripts/package-firmware.sh" || { 
    echo "ERROR: Packaging failed"
    exit 1
}

echo ""
echo "========================================"
echo "Build completed successfully!"
echo "========================================"
echo ""
echo "Output files in: ${OUTPUT_DIR}"
echo ""
echo "Files:"
ls -lh "${OUTPUT_DIR}" 2>/dev/null | tail -n +2 || true
echo ""
if [ -d "${OUTPUT_DIR}/packages" ]; then
    echo "APK Packages:"
    ls -lh "${OUTPUT_DIR}/packages/"/*.apk 2>/dev/null || true
    echo ""
fi
echo "Next steps:"
echo "1. Copy ${OUTPUT_DIR}/ax6600-alpine-factory.bin to TFTP server"
echo "2. Connect to router TTL serial (3.3V, 115200 baud)"
echo "3. Flash using U-Boot commands (see flash-commands.txt)"
echo ""
