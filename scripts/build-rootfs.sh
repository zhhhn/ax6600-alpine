#!/bin/bash
# Create Alpine Linux rootfs for JDCloud AX6600

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJ_DIR}/build"
OUTPUT_DIR="${PROJ_DIR}/out"
ROOTFS_DIR="${BUILD_DIR}/alpine-rootfs"
OVERLAY_DIR="${PROJ_DIR}/rootfs-overlay"
ALPINE_VERSION="v3.19"
ARCH="aarch64"

info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Setup base directories
setup_dirs() {
    info "Setting up rootfs directories..."
    rm -rf "${ROOTFS_DIR}"
    mkdir -p "${ROOTFS_DIR}"/{bin,dev,etc,lib,media,mnt,proc,root,run,sbin,srv,sys,tmp,usr,var}
    mkdir -p "${ROOTFS_DIR}/usr"/{bin,sbin,lib}
    mkdir -p "${ROOTFS_DIR}/var"/{cache,lib,lock,log,run,tmp,spool}
    mkdir -p "${ROOTFS_DIR}/etc/runlevels"/{boot,default,shutdown,sysinit}
    mkdir -p "${ROOTFS_DIR}/etc/init.d"
    chmod 1777 "${ROOTFS_DIR}/tmp"
    chmod 755 "${ROOTFS_DIR}" "${ROOTFS_DIR}/root"
}

# Create device nodes
create_devices() {
    info "Creating device nodes..."
    
    cd "${ROOTFS_DIR}/dev"
    
    # Basic devices (non-fatal for CI environments without mknod capability)
    mknod -m 666 null c 1 3 2>/dev/null || warn "Cannot create null device (running in container?)"
    mknod -m 666 zero c 1 5 2>/dev/null || true
    mknod -m 666 random c 1 8 2>/dev/null || true
    mknod -m 666 urandom c 1 9 2>/dev/null || true
    mknod -m 666 tty c 5 0 2>/dev/null || true
    mknod -m 600 console c 5 1 2>/dev/null || true
    mknod -m 666 full c 1 7 2>/dev/null || true
    
    # Serial ports
    mknod -m 660 ttyMSM0 c 4 64 2>/dev/null || true
    
    # Loop devices
    mknod -m 660 loop0 b 7 0 2>/dev/null || true
    mknod -m 660 loop1 b 7 1 2>/dev/null || true
    
    # Block devices
    mkdir -p mmcblk0 mmcblk0p1 mmcblk0p2 mmcblk0p3 mmcblk0p4 mmcblk0p5
    mknod -m 660 mmcblk0 b 179 0 2>/dev/null || true
    for i in $(seq 1 30); do
        mknod -m 660 mmcblk0p${i} b 179 ${i} 2>/dev/null || true
    done
    
    # PTY
    mkdir -p pts
    mknod -m 666 ptmx c 5 2 2>/dev/null || true
    
    # Create links
    ln -sf /proc/self/fd fd
    ln -sf /proc/self/fd/0 stdin
    ln -sf /proc/self/fd/1 stdout
    ln -sf /proc/self/fd/2 stderr
}

# Install Alpine base using static apk
install_alpine_base() {
    info "Installing Alpine base system..."
    
    # Download static apk if not available
    local APK_STATIC="${BUILD_DIR}/apk.static"
    if [ ! -f "${APK_STATIC}" ]; then
        info "Downloading static apk..."
        wget -q "https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic/v2.14.10/x86_64/apk.static" \
            -O "${APK_STATIC}" || {
            error "Failed to download apk.static"
            exit 1
        }
        chmod +x "${APK_STATIC}"
    fi
    
    # Setup repositories
    mkdir -p "${ROOTFS_DIR}/etc/apk/keys"
    cat > "${ROOTFS_DIR}/etc/apk/repositories" << EOF
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/main
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/community
EOF
    
    # Download Alpine keys from GitHub mirror (more reliable in CI)
    local KEYS="alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub
alpine-devel@lists.alpinelinux.org-5261cecb.rsa.pub
alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub"
    
    for key in ${KEYS}; do
        # Try multiple sources
        wget -q "https://raw.githubusercontent.com/alpine-linux/alpine-keys/master/${key}" \
            -O "${ROOTFS_DIR}/etc/apk/keys/${key}" 2>/dev/null || \
        wget -q "https://git.alpinelinux.org/aports/plain/main/alpine-keys/${key}" \
            -O "${ROOTFS_DIR}/etc/apk/keys/${key}" 2>/dev/null || \
        warn "Failed to download key: ${key}"
    done
    
    # Install base packages ( tolerant of post-install errors in CI containers)
    local BASE_PKGS="alpine-baselayout musl busybox busybox-suid openrc"
    "${APK_STATIC}" add --root "${ROOTFS_DIR}" --initdb --no-cache --allow-untrusted ${BASE_PKGS} || true
    
    # Verify base packages were installed
    if [ ! -f "${ROOTFS_DIR}/bin/busybox" ] || [ ! -f "${ROOTFS_DIR}/sbin/init" ]; then
        error "Base packages were not installed correctly"
        exit 1
    fi
    info "Base packages installed successfully"
    
    # Install additional packages (tolerant of post-install errors)
    local EXTRA_PKGS="e2fsprogs dosfstools util-linux kmod wireless-tools wpa_supplicant
iw dnsmasq nftables iptables iproute2 bridge-utils ethtool tcpdump curl wget
ca-certificates openssl dropbear rsync tar gzip xz vim nano htop chrony
tzdata eudev procps coreutils findutils grep sed gawk"
    
    "${APK_STATIC}" add --root "${ROOTFS_DIR}" --no-cache --allow-untrusted ${EXTRA_PKGS} || true
    
    # Verify at least some critical packages were installed
    if [ -f "${ROOTFS_DIR}/usr/bin/wget" ] || [ -f "${ROOTFS_DIR}/usr/bin/curl" ]; then
        info "Additional packages installed"
    else
        warn "Some additional packages may have failed to install"
    fi
}

# Apply overlay
apply_overlay() {
    info "Applying rootfs overlay..."
    
    if [ -d "${OVERLAY_DIR}" ]; then
        cp -r "${OVERLAY_DIR}"/* "${ROOTFS_DIR}/" 2>/dev/null || true
    fi
    
    # Ensure proper permissions
    chmod 755 "${ROOTFS_DIR}/etc/init.d/"* 2>/dev/null || true
}

# Configure services
configure_services() {
    info "Configuring services..."
    
    cd "${ROOTFS_DIR}/etc/runlevels/default"
    
    # Enable services
    for svc in devfs dmesg syslog network firewall dnsmasq; do
        if [ -f "${ROOTFS_DIR}/etc/init.d/${svc}" ]; then
            ln -sf "/etc/init.d/${svc}" "${svc}" 2>/dev/null || true
        fi
    done
    
    # Enable dropbear if exists
    if [ -f "${ROOTFS_DIR}/etc/init.d/dropbear" ]; then
        ln -sf "/etc/init.d/dropbear" dropbear 2>/dev/null || true
    fi
    
    # Enable WiFi if hostapd exists
    if [ -f "${ROOTFS_DIR}/etc/init.d/wifi" ]; then
        ln -sf "/etc/init.d/wifi" wifi 2>/dev/null || true
    fi
}

# Create root password
set_root_password() {
    info "Setting root password..."
    
    # Set empty password (change later)
    echo "root:::0:::::" > "${ROOTFS_DIR}/etc/shadow"
    echo "root:x:0:0:root:/root:/bin/ash" > "${ROOTFS_DIR}/etc/passwd"
}

# Create image
create_image() {
    info "Creating rootfs image..."
    
    # Clean up
    rm -rf "${ROOTFS_DIR}/var/cache/apk/*"
    
    # Create tar.gz archive
    cd "${ROOTFS_DIR}"
    tar -czf "${OUTPUT_DIR}/alpine-rootfs.tar.gz" . 2>/dev/null || {
        warn "Failed to create tar.gz, creating cpio instead"
        find . | cpio -H newc -o | gzip > "${OUTPUT_DIR}/alpine-rootfs.cpio.gz"
    }
    
    # Create ext4 image (for direct flashing)
    local IMAGE_SIZE="512M"
    dd if=/dev/zero of="${OUTPUT_DIR}/alpine-rootfs.img" bs=1 count=0 seek=${IMAGE_SIZE} 2>/dev/null
    mkfs.ext4 -F "${OUTPUT_DIR}/alpine-rootfs.img" -d "${ROOTFS_DIR}" 2>/dev/null || {
        warn "Failed to create ext4 image with mkfs.ext4"
        # Fallback: mount and copy
        warn "Skipping ext4 image creation"
    }
    
    # Compress image
    if [ -f "${OUTPUT_DIR}/alpine-rootfs.img" ]; then
        gzip -k "${OUTPUT_DIR}/alpine-rootfs.img"
    fi
    
    info "Rootfs images created"
}

# Create initramfs
create_initramfs() {
    info "Creating initramfs..."
    
    local INITRAMFS_DIR="${BUILD_DIR}/initramfs"
    rm -rf "${INITRAMFS_DIR}"
    mkdir -p "${INITRAMFS_DIR}"/{bin,sbin,etc,proc,sys,dev,lib,lib64,mnt,root,tmp,usr}
    
    # Create init script
    cat > "${INITRAMFS_DIR}/init" << 'INITSCRIPT'
#!/bin/sh

# Mount basic filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Show boot message
echo "========================================"
echo "Alpine Linux Initramfs"
echo "JDCloud AX6600"
echo "========================================"

# Wait for mmcblk0
for i in $(seq 1 30); do
    if [ -e /dev/mmcblk0p18 ]; then
        break
    fi
    echo "Waiting for root device... ($i)"
    sleep 1
done

# Mount rootfs
if [ -e /dev/mmcblk0p18 ]; then
    mount -t ext4 /dev/mmcblk0p18 /mnt/root || {
        echo "Failed to mount rootfs, starting emergency shell"
        exec /bin/sh
    }
else
    echo "Root device not found, starting emergency shell"
    exec /bin/sh
fi

# Switch to real root
exec switch_root /mnt/root /sbin/init
INITSCRIPT
    chmod +x "${INITRAMFS_DIR}/init"
    
    # Create busybox links
    cd "${INITRAMFS_DIR}/bin"
    for cmd in sh mount umount echo cat mkdir mknod chmod sleep switch_root; do
        ln -sf busybox ${cmd} 2>/dev/null || true
    done
    
    # Create cpio archive
    cd "${INITRAMFS_DIR}"
    find . | cpio -H newc -o | gzip > "${OUTPUT_DIR}/initramfs.cpio.gz"
    
    info "Initramfs created: ${OUTPUT_DIR}/initramfs.cpio.gz"
}

# Main execution
setup_dirs
create_devices
install_alpine_base
apply_overlay
configure_services
set_root_password
create_image
create_initramfs
info "Rootfs build completed!"