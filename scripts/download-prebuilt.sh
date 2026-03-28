#!/bin/bash
# Download pre-built kernel from OpenWrt as base

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${PROJ_DIR}/out"
BUILD_DIR="${PROJ_DIR}/build"

mkdir -p "${OUTPUT_DIR}"

echo "Downloading pre-built OpenWrt kernel for IPQ60xx..."

# OpenWrt IPQ60xx kernel
KERNEL_URL="https://downloads.openwrt.org/releases/23.05.3/targets/ipq807x/generic/openwrt-23.05.3-ipq807x-generic-jdcloud_re-cs-02-initramfs-fit-uImage.itb"

wget -q --show-progress "$KERNEL_URL" -O "${BUILD_DIR}/openwrt-base.itb" || {
    echo "Failed to download OpenWrt kernel"
    exit 1
}

echo "Extracting kernel components..."

# Use dumpimage to extract
if command -v dumpimage &> /dev/null; then
    cd "${BUILD_DIR}"
    dumpimage -i openwrt-base.itb -p 0 kernel.gz -O "${OUTPUT_DIR}/Image.gz"
    dumpimage -i openwrt-base.itb -p 1 fdt -O "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb"
    echo "Kernel extracted successfully"
else
    echo "dumpimage not available, using direct copy"
    cp "${BUILD_DIR}/openwrt-base.itb" "${OUTPUT_DIR}/ax6600-alpine-kernel.bin"
fi

echo "Done!"
