#!/bin/bash
# Package firmware for JDCloud AX6600
# Creates FIT (Flattened Image Tree) image

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${PROJ_DIR}/out"
BUILD_DIR="${PROJ_DIR}/build"

# FIT image configuration
KERNEL_LOADADDR="0x44000000"
DTB_LOADADDR="0x43000000"
INITRD_LOADADDR="0x48000000"

info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Create FIT image source file
create_fit_source() {
    info "Creating FIT image source..."
    
    # Check for required files
    if [ ! -f "${OUTPUT_DIR}/Image.gz" ]; then
        error "Kernel Image.gz not found!"
        exit 1
    fi
    
    if [ ! -f "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb" ]; then
        error "Device tree not found!"
        exit 1
    fi
    
    if [ ! -f "${OUTPUT_DIR}/initramfs.cpio.gz" ]; then
        info "Creating minimal initramfs..."
        create_minimal_initramfs
    fi
    
    cat > "${BUILD_DIR}/ax6600-alpine.its" << EOF
/dts-v1/;

/ {
    description = "JDCloud AX6600 Alpine Linux FIT Image";

    images {
        kernel {
            description = "Linux Kernel";
            data = /incbin/("${OUTPUT_DIR}/Image.gz");
            type = "kernel";
            arch = "arm64";
            os = "linux";
            compression = "gzip";
            load = <${KERNEL_LOADADDR}>;
            entry = <${KERNEL_LOADADDR}>;
            hash-1 {
                algo = "sha256";
            };
        };

        fdt {
            description = "Flattened Device Tree";
            data = /incbin/("${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            load = <${DTB_LOADADDR}>;
            hash-1 {
                algo = "sha256";
            };
        };

        initramfs {
            description = "Initramfs";
            data = /incbin/("${OUTPUT_DIR}/initramfs.cpio.gz");
            type = "ramdisk";
            arch = "arm64";
            os = "linux";
            compression = "gzip";
            load = <${INITRD_LOADADDR}>;
            entry = <${INITRD_LOADADDR}>;
            hash-1 {
                algo = "sha256";
            };
        };
    };

    configurations {
        default = "standard";

        standard {
            description = "Standard Boot";
            kernel = "kernel";
            fdt = "fdt";
            loadables = "initramfs";
            hash-1 {
                algo = "sha256";
            };
        };

        noinitrd {
            description = "Boot without initramfs";
            kernel = "kernel";
            fdt = "fdt";
            hash-1 {
                algo = "sha256";
            };
        };
    };
};
EOF
}

# Create minimal initramfs
create_minimal_initramfs() {
    info "Creating minimal initramfs..."
    
    local INITRAMFS_DIR="${BUILD_DIR}/initramfs-minimal"
    rm -rf "${INITRAMFS_DIR}"
    mkdir -p "${INITRAMFS_DIR}"/{bin,sbin,etc,proc,sys,dev,lib,mnt,root,tmp}
    
    # Create init script
    cat > "${INITRAMFS_DIR}/init" << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
echo "JDCloud AX6600 - Alpine Linux"
echo "Waiting for root device..."
for i in $(seq 1 30); do
    [ -e /dev/mmcblk0p18 ] && break
    sleep 1
done
mount -t ext4 /dev/mmcblk0p18 /mnt/root || exec /bin/sh
exec switch_root /mnt/root /sbin/init
EOF
    chmod +x "${INITRAMFS_DIR}/init"
    
    # Package
    cd "${INITRAMFS_DIR}"
    find . | cpio -H newc -o | gzip > "${OUTPUT_DIR}/initramfs.cpio.gz"
}

# Build FIT image
build_fit_image() {
    info "Building FIT image..."
    
    cd "${BUILD_DIR}"
    
    # Check for mkimage
    if ! command -v mkimage &> /dev/null; then
        info "mkimage not found, using raw kernel+dtb..."
        cat "${OUTPUT_DIR}/Image.gz" "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb" > "${OUTPUT_DIR}/ax6600-alpine-kernel.bin"
        return 0
    fi
    
    # Create FIT image
    if mkimage -f "ax6600-alpine.its" "${OUTPUT_DIR}/ax6600-alpine.itb" 2>/dev/null; then
        info "FIT image created: ${OUTPUT_DIR}/ax6600-alpine.itb"
    else
        info "Failed to create FIT image, using raw kernel"
        cp "${OUTPUT_DIR}/Image.gz" "${OUTPUT_DIR}/ax6600-alpine-kernel.bin"
    fi
}

# Create factory image
create_factory_image() {
    info "Creating factory image..."
    
    local FACTORY_IMAGE="${OUTPUT_DIR}/ax6600-alpine-factory.bin"
    
    # Use FIT image if available, otherwise use raw kernel
    local KERNEL_IMAGE="${OUTPUT_DIR}/ax6600-alpine.itb"
    if [ ! -f "$KERNEL_IMAGE" ]; then
        KERNEL_IMAGE="${OUTPUT_DIR}/ax6600-alpine-kernel.bin"
    fi
    
    if [ ! -f "$KERNEL_IMAGE" ]; then
        error "No kernel image found!"
        return 1
    fi
    
    # Create factory image
    dd if="$KERNEL_IMAGE" of="${FACTORY_IMAGE}" bs=1 2>/dev/null
    local KERNEL_SIZE=$(stat -c%s "${FACTORY_IMAGE}" 2>/dev/null || echo 0)
    local PAD_SIZE=$((6 * 1024 * 1024 - KERNEL_SIZE))
    
    if [ $PAD_SIZE -gt 0 ]; then
        dd if=/dev/zero bs=1 count=$PAD_SIZE 2>/dev/null >> "${FACTORY_IMAGE}"
    fi
    
    # Append rootfs
    if [ -f "${OUTPUT_DIR}/alpine-rootfs.img.gz" ]; then
        cat "${OUTPUT_DIR}/alpine-rootfs.img.gz" >> "${FACTORY_IMAGE}"
    elif [ -f "${OUTPUT_DIR}/alpine-rootfs.tar.gz" ]; then
        cat "${OUTPUT_DIR}/alpine-rootfs.tar.gz" >> "${FACTORY_IMAGE}"
    fi
    
    info "Factory image created: ${FACTORY_IMAGE}"
}

# Create flash script
create_flash_script() {
    info "Creating flash script..."
    
    cat > "${OUTPUT_DIR}/flash-commands.txt" << 'EOF'
# Flash commands for U-Boot (JDCloud AX6600)
#
# Setup:
# 1. Connect TTL serial (3.3V, 115200 baud)
# 2. Setup TFTP server on PC (IP: 192.168.10.1)
# 3. Copy ax6600-alpine-factory.bin to TFTP root
#
# Commands:

setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10
ping ${serverip}

# Flash kernel to HLOS partition
tftpboot 0x44000000 ax6600-alpine-factory.bin
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000

reset
EOF

    cat > "${OUTPUT_DIR}/install.sh" << 'EOF'
#!/bin/sh
echo "Installing Alpine Linux..."
mkfs.ext4 -F /dev/mmcblk0p18
mount /dev/mmcblk0p18 /mnt
tar -xzf /alpine-rootfs.tar.gz -C /mnt
umount /mnt
echo "Installation complete!"
EOF
    chmod +x "${OUTPUT_DIR}/install.sh"
    
    info "Flash scripts created"
}

# Generate checksums
generate_checksums() {
    info "Generating checksums..."
    
    cd "${OUTPUT_DIR}"
    for f in *.bin *.itb *.gz *.img; do
        [ -f "$f" ] && sha256sum "$f" >> SHA256SUMS 2>/dev/null
    done
    
    info "Checksums saved"
}

# Main
main() {
    info "Packaging firmware for JDCloud AX6600..."
    
    # Check required files
    local REQUIRED_FILES=(
        "${OUTPUT_DIR}/Image.gz"
        "${OUTPUT_DIR}/ipq6018-jdcloud-ax6600.dtb"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            error "Missing required file: $file"
            exit 1
        fi
    done
    
    # Package steps
    create_fit_source
    build_fit_image
    create_factory_image
    create_flash_script
    generate_checksums
    
    info "Firmware packaging completed!"
    info "Output files in: ${OUTPUT_DIR}"
    ls -lh "${OUTPUT_DIR}"
}

main
