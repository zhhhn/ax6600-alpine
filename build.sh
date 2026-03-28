#!/bin/bash
# Main build script for JDCloud AX6600 Alpine Linux

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJ_DIR}/build"
OUTPUT_DIR="${PROJ_DIR}/out"

echo "========================================"
echo "JDCloud AX6600 Alpine Linux Build System"
echo "========================================"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Check if we should skip kernel build
if [ "${SKIP_KERNEL:-}" != "1" ]; then
    echo "[1/3] Building kernel..."
    bash "${PROJ_DIR}/scripts/build-kernel.sh" all || { 
        echo "ERROR: Kernel build failed"
        exit 1
    }
    echo ""
fi

# Check if we should skip rootfs build
if [ "${SKIP_ROOTFS:-}" != "1" ]; then
    echo "[2/3] Building rootfs..."
    bash "${PROJ_DIR}/scripts/build-rootfs.sh" || { 
        echo "ERROR: Rootfs build failed"
        exit 1
    }
    echo ""
fi

# Package firmware
echo "[3/3] Packaging firmware..."
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
echo "Next steps:"
echo "1. Copy ${OUTPUT_DIR}/ax6600-alpine-factory.bin to TFTP server"
echo "2. Connect to router TTL serial (3.3V, 115200 baud)"
echo "3. Flash using U-Boot commands (see flash-commands.txt)"
echo ""
