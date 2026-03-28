# JDCloud AX6600 Alpine Linux Installation Guide

## Prerequisites

### Hardware
- JDCloud AX6600 (Athena) router
- USB to TTL serial adapter (3.3V level)
- Ethernet cable
- Computer with Linux/macOS/Windows

### Software
- TFTP server software
- Serial terminal (minicom, screen, or PuTTY)
- `aarch64-linux-gnu-` toolchain (for building)

## Building from Source

```bash
# 1. Clone or navigate to project
cd projects/ax6600-alpine

# 2. Build everything
./build.sh

# 3. Output files will be in out/ directory
ls -la out/
```

## Flashing Methods

### Method 1: U-Boot TFTP (Recommended)

1. **Setup TFTP Server**
   ```bash
   # On your PC (IP: 192.168.10.1)
   sudo apt-get install tftpd-hpa
   sudo cp out/ax6600-alpine-factory.bin /var/lib/tftpboot/
   ```

2. **Connect Serial**
   - Connect USB-TTL to router (3.3V, TX, RX, GND)
   - Open serial terminal: `minicom -D /dev/ttyUSB0 -b 115200`

3. **Enter U-Boot**
   - Power on router
   - Press Enter repeatedly during boot
   - You should see `IPQ6018#` prompt

4. **Flash Firmware**
   ```bash
   # In U-Boot console
   setenv serverip 192.168.10.1
   setenv ipaddr 192.168.10.10
   ping ${serverip}
   
   # Flash kernel
   tftpboot 0x44000000 ax6600-alpine-factory.bin
   mmc erase 0x00004022 0x3000
   mmc write 0x44000000 0x00004022 0x3000
   
   # Reset
   reset
   ```

### Method 2: U-Boot Web UI

1. Hold reset button while powering on
2. Wait for blue LED (failsafe mode)
3. Access http://192.168.1.1
4. Upload `ax6600-alpine-factory.bin`
5. Wait for green LED (success)

### Method 3: From Running OpenWrt

If you already have OpenWrt installed:

```bash
# Copy firmware to router
scp out/ax6600-alpine-factory.bin root@192.168.1.1:/tmp/

# SSH to router
ssh root@192.168.1.1

# Flash kernel partition
dd if=/tmp/ax6600-alpine-factory.bin of=/dev/mmcblk0p16 bs=512

# Reboot
reboot
```

## First Boot

1. **Connect to Router**
   - LAN port to PC
   - Default IP: 192.168.1.1

2. **Login**
   - SSH: `ssh root@192.168.1.1`
   - Serial: 115200 baud
   - No password (set with `passwd`)

3. **Configure Network**
   ```bash
   # WAN (DHCP by default)
   udhcpc -i eth0
   
   # Or set static IP
   ifconfig eth0 192.168.0.100 netmask 255.255.255.0
   route add default gw 192.168.0.1
   ```

4. **WiFi Configuration**
   ```bash
   # Edit WiFi config
   vi /etc/hostapd/hostapd.conf
   
   # Change SSID and password
   ssid=YourSSID
   wpa_passphrase=YourPassword
   
   # Restart WiFi
   rc-service wifi restart
   ```

## Post-Installation

### Install Additional Packages
```bash
apk update
apk add docker haveged
```

### Enable Services
```bash
rc-update add docker default
rc-service docker start
```

### Backup Configuration
```bash
tar -czf /mnt/config-backup.tar.gz /etc
```

## Troubleshooting

### No Serial Output
- Check baud rate: 115200
- Verify TX/RX are crossed
- Ensure 3.3V level (not 5V!)

### Boot Fails
- Check kernel partition (mmcblk0p16)
- Verify rootfs partition (mmcblk0p18)
- Use serial to see boot messages

### No Network
- Check cable connection
- Verify interface names: `ip link`
- Check network config: `cat /etc/network/interfaces`

### WiFi Not Working
- Check ART partition backup
- Verify ath11k firmware
- Check dmesg for errors

## Recovery

If the router doesn't boot:

1. Enter U-Boot failsafe (hold reset)
2. Flash back OpenWrt or stock firmware
3. Or use USB 9008 mode for emergency recovery

## Support

- Project: JDCloud AX6600 Alpine Linux
- Based on: OpenWrt IPQ60xx support
- Kernel: Linux 6.6 LTS
- Rootfs: Alpine Linux 3.19
