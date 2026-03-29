# ClawUI Applications - Alpine APK Packages

## Overview

This directory contains ClawUI applications packaged as Alpine Linux `.apk` packages for the JDCloud AX6600 router.

## Available Applications

| Application | Description | Status |
|------------|-------------|--------|
| **kms** | KMS activation server for Windows/Office | ✅ Ready |
| **nps** | NPS reverse proxy client | ✅ Ready |
| **aria2** | Aria2 download manager | ✅ Ready |
| **wireguard** | WireGuard VPN configuration | ✅ Ready |
| **pppoe** | PPPoE configuration | ✅ Ready |
| **frp** | FRP reverse proxy | ✅ Ready |
| **multiwan** | Multi-WAN load balancing | ✅ Ready |
| **adblock** | Ad blocking service | ✅ Ready |
| **qos** | QoS traffic shaping | ✅ Ready |
| **portforward** | Port forwarding rules | ✅ Ready |
| **ddns** | Dynamic DNS client | ✅ Ready |
| **diag** | Network diagnostics | ✅ Ready |
| **backup** | Configuration backup | ✅ Ready |
| **routes** | Static route management | ✅ Ready |
| **traffic** | Traffic monitoring | ✅ Ready |

## Building APK Packages

### Method 1: Simple Build (No abuild required)

```bash
cd /path/to/ax6600-alpine-clean

# Build all packages
./scripts/build-apk-simple.sh all

# Build specific package
./scripts/build-apk-simple.sh build kms
./scripts/build-apk-simple.sh build nps
./scripts/build-apk-simple.sh build aria2

# Install package to rootfs
./scripts/build-apk-simple.sh install out/packages/kms-server-1.0.0-r0_noarch.apk build/alpine-rootfs
```

### Method 2: Full abuild Build (Requires Alpine build tools)

```bash
# Install build tools (on Alpine)
apk add abuild devtools

# Build all packages
./scripts/build-apk-packages.sh all

# Build specific package
./scripts/build-apk-packages.sh build kms
```

## Package Structure

Each application follows the Alpine package structure:

```
apps/<appname>/
├── APKBUILD          # Package build definition
├── manifest.json     # ClawUI app manifest
├── www/              # Web interface files
│   └── index.html
├── api/
│   └── handler.sh    # API endpoints
├── i18n/
│   └── translations.json
├── <appname>.init    # OpenRC init script
├── <appname>.conf    # Default configuration
└── post-install.sh   # Optional post-install script
```

## Installing Packages

### During Rootfs Build

Packages are automatically included when building the rootfs:

```bash
./scripts/build-rootfs.sh
```

### Manual Installation

```bash
# Copy APK to router
scp out/packages/*.apk root@router:/tmp/

# Install on router
ssh root@router
apk add --allow-untrusted /tmp/kms-server-1.0.0-r0_noarch.apk
/etc/init.d/kms-server start
```

### Add to Repository

```bash
# Create package repository
./scripts/build-apk-packages.sh repo

# Add repository to /etc/apk/repositories
echo "http://router-ip/packages" >> /etc/apk/repositories

# Install from repository
apk update
apk add kms-server nps-client aria2
```

## Application Details

### KMS Server

- **Port:** 1688 (default)
- **Description:** KMS activation server for Windows and Office
- **Usage:**
  ```bash
  # Windows
  slmgr /skms <router-ip>:1688
  slmgr /ato
  
  # Office
  cscript ospp.vbs /sethst:<router-ip>
  cscript ospp.vbs /act
  ```

### NPS Client

- **Description:** Reverse proxy client for remote access
- **Features:** HTTP/HTTPS proxy, TCP/UDP tunnel, SOCKS5, P2P
- **Configuration:** `/etc/nps/npc.conf`
- **Download binary:**
  ```bash
  ./clawui/apps/nps/download-npc.sh
  ```

### Aria2 Download Manager

- **RPC Port:** 6800 (default)
- **Download Dir:** `/var/lib/aria2/downloads`
- **Features:** HTTP/HTTPS/FTP/BitTorrent/Metalink support
- **Web UI:** Access via ClawUI interface
- **CLI:**
  ```bash
  aria2c -x 16 -s 16 https://example.com/file.zip
  ```

## Configuration

Each application has configuration files in:

- `/etc/conf.d/<appname>` - Service configuration
- `/etc/<appname>/` - Application-specific config

## Troubleshooting

### Check Service Status

```bash
rc-status | grep -E "kms|nps|aria2"
```

### View Logs

```bash
tail -f /var/log/kms-server.log
tail -f /var/log/nps-client.log
tail -f /var/log/aria2.log
```

### Restart Services

```bash
/etc/init.d/kms-server restart
/etc/init.d/nps-client restart
/etc/init.d/aria2 restart
```

## Development

### Creating New Applications

1. Create app directory:
   ```bash
   mkdir -p apps/myapp/{www,api,i18n}
   ```

2. Create APKBUILD (copy from existing app)

3. Create manifest.json

4. Create web UI (www/index.html)

5. Create API handler (api/handler.sh)

6. Create init script (<appname>.init)

7. Build package:
   ```bash
   ./scripts/build-apk-simple.sh build myapp
   ```

## License

MIT License - See individual application licenses
