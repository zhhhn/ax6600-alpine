# JDCloud AX6600 Alpine Linux - Ready for Build

**Status**: ✅ Complete and Ready  
**Date**: 2026-03-27  
**Files**: 33 files, 212KB total  

---

## Quick Start

```bash
# Build everything
./build.sh

# Or build components separately
./scripts/build-kernel.sh all      # Kernel
./scripts/build-rootfs.sh            # Rootfs
./scripts/package-firmware.sh        # Package
```

---

## What's Included

### Core Components
- ✅ Linux 6.6.22 kernel with IPQ60xx support
- ✅ Device tree for JDCloud AX6600
- ✅ Alpine Linux 3.19 rootfs with OpenRC
- ✅ FIT image packaging for U-Boot
- ✅ Factory image ready for flashing

### Router Features
- ✅ Network: WAN (DHCP), LAN (192.168.1.1/24)
- ✅ Firewall: nftables with NAT
- ✅ DNS/DHCP: dnsmasq
- ✅ WiFi: hostapd (2.4G + 5G)
- ✅ SSH: dropbear
- ✅ Services: OpenRC init system

### Documentation
- ✅ README.md - Project overview
- ✅ INSTALL.md - Flashing instructions
- ✅ MANIFEST.md - Firmware components
- ✅ CHECKLIST.md - Development checklist

---

## Project Structure

```
projects/ax6600-alpine/
├── build.sh                    # Main build script
├── configs/
│   └── ipq6018-jdcloud-ax6600.dts    # Device tree
├── rootfs-overlay/             # Rootfs customizations
│   ├── etc/
│   │   ├── dnsmasq.conf
│   │   ├── fstab
│   │   ├── hostapd/
│   │   ├── init.d/
│   │   ├── network/interfaces
│   │   ├── nftables.conf
│   │   └── ...
│   └── ...
├── scripts/
│   ├── build-kernel.sh         # Kernel builder
│   ├── build-rootfs.sh         # Rootfs builder
│   └── package-firmware.sh     # Firmware packager
└── docs/
    ├── README.md
    ├── INSTALL.md
    ├── MANIFEST.md
    └── CHECKLIST.md
```

---

## Build Output

After running `./build.sh`, you'll get:

```
out/
├── Image.gz                    # Kernel
├── ipq6018-jdcloud-ax6600.dtb  # Device tree
├── initramfs.cpio.gz           # Initramfs
├── ax6600-alpine.itb           # FIT image
├── ax6600-alpine-factory.bin   # Flashable image
├── alpine-rootfs.tar.gz        # Rootfs
└── flash-commands.txt          # Flash instructions
```

---

## Flashing

### Method 1: U-Boot TFTP
```bash
# On router (U-Boot console)
setenv serverip 192.168.10.1
tftpboot 0x44000000 ax6600-alpine-factory.bin
mmc erase 0x00004022 0x3000
mmc write 0x44000000 0x00004022 0x3000
reset
```

### Method 2: U-Boot Web UI
1. Hold reset button while powering on
2. Access http://192.168.1.1
3. Upload factory.bin

---

## Post-Flash

- Default IP: 192.168.1.1
- Login: root (no password)
- WiFi: AX6600-2.4G / AX6600-5G (password: 12345678)

---

## Next Steps

1. Run `./build.sh` to generate firmware
2. Flash to router using U-Boot
3. Configure network and WiFi
4. Install additional packages with `apk`

---

**Ready for building and flashing!**
