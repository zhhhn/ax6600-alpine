#!/bin/bash
# Auto-development script for JDCloud AX6600 Alpine Linux
# Run this script every 10 minutes via cron or manually

PROJ_DIR="/home/node/.openclaw/workspace/projects/ax6600-alpine"
LOG_FILE="${PROJ_DIR}/logs/auto-dev.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

cd "${PROJ_DIR}" || exit 1

log "=== Starting auto-dev check ==="

# Check if build is needed
if [ ! -f "out/ax6600-alpine-factory.bin" ]; then
    log "Firmware not found, starting build..."
    ./build.sh >> "${LOG_FILE}" 2>&1
    log "Build completed"
else
    log "Firmware exists: $(ls -lh out/ax6600-alpine-factory.bin)"
fi

# Check kernel
if [ ! -f "out/Image.gz" ]; then
    log "Kernel not found, building kernel..."
    ./scripts/build-kernel.sh all >> "${LOG_FILE}" 2>&1
fi

# Check rootfs
if [ ! -f "out/alpine-rootfs.tar.gz" ]; then
    log "Rootfs not found, building rootfs..."
    ./scripts/build-rootfs.sh >> "${LOG_FILE}" 2>&1
fi

# Package if needed
if [ ! -f "out/ax6600-alpine.itb" ]; then
    log "FIT image not found, packaging..."
    ./scripts/package-firmware.sh >> "${LOG_FILE}" 2>&1
fi

log "=== Auto-dev check completed ==="
echo ""
