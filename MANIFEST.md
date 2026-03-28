# JDCloud AX6600 Alpine Linux - Firmware Manifest

**Version**: 1.0.0  
**Date**: 2026-03-27  
**Kernel**: Linux 6.6.22 LTS  
**Rootfs**: Alpine Linux 3.19  

---

## Firmware Components

### 1. Kernel
- **File**: `Image.gz`
- **Arch**: ARM64 (aarch64)
- **Size**: ~8-10 MB (compressed)
- **Load Address**: 0x44000000
- **Features**:
  - IPQ6010 SoC support
  - ath11k WiFi driver
  - SDHCI-MSM storage driver
  - MSM GENI UART serial
  - QCA EMAC network
  - PCIe support
  - USB3.0 DWC3

### 2. Device Tree
- **File**: `ipq6018-jdcloud-ax6600.dtb`
- **Load Address**: 0x43000000
- **Hardware**:
  - CPU: 4× Cortex-A53 @ 1.8GHz
  - WiFi: QCN5022 (2.4G) + QCN5052 (5G) + QCN9074 (5G PCIe)
  - Ethernet: 1×2.5G WAN + 4×1G LAN
  - Storage: 64GB eMMC
  - USB: 1×USB3.0

### 3. Root Filesystem
- **File**: `alpine-rootfs.tar.gz`
- **Size**: ~15-20 MB (compressed)
- **Base**: Alpine Linux 3.19
- **Init**: OpenRC
- **Packages**:
  - Base: busybox, musl, openrc
  - Network: dnsmasq, nftables, iptables, iproute2
  - WiFi: hostapd, wpa_supplicant, iw
  - Tools: dropbear, curl, wget, vim

### 4. Initramfs
- **File**: `initramfs.cpio.gz`
- **Purpose**: Early boot, mounts rootfs
- **Size**: ~2-3 MB

### 5. FIT Image
- **File**: `ax6600-alpine.itb`
- **Format**: Flattened Image Tree
- **Contains**: Kernel + DTB + Initramfs
- **Verification**: SHA256 hashes

### 6. Factory Image
- **File**: `ax6600-alpine-factory.bin`
- **Size**: ~30-40 MB
- **Structure**:
  - Offset 0: Kernel FIT (6MB padded)
  - Offset 6MB: Rootfs
- **Flash to**: /dev/mmcblk0p16 (HLOS)

---

## File Structure

```
out/
├── Image.gz                          # Kernel image
├── ipq6018-jdcloud-ax6600.dtb        # Device tree blob
├── initramfs.cpio.gz                 # Initramfs
├── modules.tar.gz                    # Kernel modules
├── ax6600-alpine.itb                # FIT image (kernel+dtb+initramfs)
├── ax6600-alpine-factory.bin        # Factory flash image
├── alpine-rootfs.tar.gz             # Rootfs archive
├── alpine-rootfs.img.gz             # Rootfs ext4 image
├── flash-commands.txt               # U-Boot flash commands
├── install.sh                       # Installation script
└── SHA256SUMS                       # Checksums
```

---

## Partition Layout

```
/dev/mmcblk0 (64GB eMMC)
├── p1  (0:SBL1)        768KB    - Primary bootloader
├── p13 (0:APPSBL)      640KB    - U-Boot
├── p15 (0:ART)         256KB    - WiFi calibration (BACKUP!)
├── p16 (0:HLOS)        6MB      - Kernel ← FLASH HERE
├── p18 (rootfs)        512MB+   - Rootfs ← FLASH HERE
└── p27 (storage)       ~55GB    - Data
```

---

## Flashing Commands

### U-Boot TFTP Method
```bash
# Setup
setenv serverip 192.168.10.1
setenv ipaddr 192.168.10.10

# Test connection
ping ${serverip}

# Download and flash
tftpboot 0x44000000 ax6600-alpine-factory.bin
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000

# Reset
reset
```

### From Linux (OpenWrt)
```bash
dd if=ax6600-alpine-factory.bin of=/dev/mmcblk0p16 bs=512
dd if=alpine-rootfs.img of=/dev/mmcblk0p18 bs=1M
```

---

## Boot Process

1. **SBL1** → Primary bootloader ( Qualcomm)
2. **U-Boot** → Loads kernel from mmcblk0p16
3. **Kernel** → Decompresses, mounts initramfs
4. **Initramfs** → Mounts rootfs from mmcblk0p18
5. **OpenRC** → Starts services (network, dnsmasq, etc.)

---

## Network Configuration

### Default Settings
- **LAN**: 192.168.1.1/24 (br-lan)
- **WAN**: DHCP (eth0)
- **WiFi 2.4G**: AX6600-2.4G / 12345678
- **WiFi 5G**: AX6600-5G / 12345678

### Interfaces
- `eth0`: WAN (2.5G port)
- `eth1-eth4`: LAN (bridged to br-lan)
- `br-lan`: Bridge interface (192.168.1.1)
- `wlan0`: 2.4GHz WiFi
- `wlan1`: 5GHz WiFi

---

## Services

| Service | Port | Description |
|---------|------|-------------|
| dropbear | 22 | SSH server |
| dnsmasq | 53 | DNS/DHCP server |
| hostapd | - | WiFi AP (2.4G) |
| hostapd | - | WiFi AP (5G) |
| nftables | - | Firewall |

---

## Known Issues

1. **NSS Acceleration**: Not fully supported (software NAT only)
2. **WiFi Firmware**: Requires proprietary ath11k firmware
3. **LED Control**: Basic support only
4. **USB**: Storage supported, network devices pending

---

## Build Information

- **Build Host**: Linux x86_64
- **Cross Compiler**: aarch64-linux-gnu-gcc
- **Kernel Config**: ipq60xx_defconfig
- **Build Date**: 2026-03-27
- **Git Commit**: (see git log)

---

## License

- Kernel: GPL v2
- Alpine Linux: MIT
- Device Tree: GPL v2
- Scripts: MIT

---

**Warning**: Flashing custom firmware may void warranty and can brick your device. Always backup ART partition before flashing!
