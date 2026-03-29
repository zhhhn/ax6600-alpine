# GitHub Actions Automated Build

This project uses GitHub Actions for automated firmware compilation.

## Build Triggers

- **Push to main/master**: Automatic build
- **Pull Request**: Build verification
- **Manual**: Workflow dispatch button

## Build Process

1. Install build tools (flex, bison, gcc, etc.)
2. Install ARM64 cross compiler
3. Run build script
4. Upload artifacts
5. Create release (on main branch push)

## Download Firmware

### Latest Release
Visit the [Releases](../../releases) page to download the latest firmware.

### Artifacts
Each build generates artifacts available for 30 days:
1. Go to [Actions](../../actions)
2. Select the latest workflow run
3. Download `ax6600-alpine-firmware` artifact

## Flashing

### Using U-Boot TFTP

1. Setup TFTP server on PC (IP: 192.168.10.1)
2. Copy `ax6600-alpine-factory.bin` to TFTP root
3. Connect to router TTL serial (3.3V, 115200 baud)
4. Power on and enter U-Boot (press Enter during boot)
5. Execute commands:
   ```
   setenv serverip 192.168.10.1
   setenv ipaddr 192.168.10.10
   tftpboot 0x44000000 ax6600-alpine-factory.bin
   mmc erase 0x00004022 0x3000
   mmc write 0x44000000 0x00004022 0x3000
   reset
   ```

### Using U-Boot Web UI

1. Hold reset button while powering on
2. Wait for blue LED
3. Access http://192.168.1.1
4. Upload `ax6600-alpine-factory.bin`
5. Wait for green LED

## Firmware Components

- **Kernel**: Linux 6.6.22 LTS with IPQ60xx support
- **Rootfs**: Alpine Linux 3.19 with OpenRC
- **Network**: dnsmasq (DHCP/DNS), nftables (firewall)
- **WiFi**: hostapd (2.4G/5G support)
- **SSH**: dropbear

## Default Settings

- LAN IP: 192.168.1.1
- SSH: root (no password - set on first login)
- WiFi: AX6600-2.4G / AX6600-5G (password: 12345678)

## Development

To build locally:

```bash
# Install dependencies
sudo apt-get install build-essential flex bison gcc-aarch64-linux-gnu

# Build
./build.sh

# Output in out/
ls -la out/
```

## License

- Kernel: GPL v2
- Alpine Linux: MIT
- Build scripts: MIT
