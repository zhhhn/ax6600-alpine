# ClawUI Apps for Alpine Linux Router

📦 Web management interfaces for Alpine Linux router applications.

## 🎯 Overview

ClawUI Apps provide web-based management interfaces for various services running on Alpine Linux routers (specifically JDCloud AX6600).

**Key Features:**
- ✅ Web-based management (no CLI needed)
- ✅ Service control (start/stop/restart)
- ✅ Configuration management
- ✅ Real-time status monitoring
- ✅ Log viewing
- ✅ Small package size (2-7 KB each)

## 📦 Available Apps

| App | Package | Description | Dependencies |
|-----|---------|-------------|--------------|
| **Aria2** | `clawui-app-aria2` | BT/HTTP download manager | aria2, curl |
| **NPS Server** | `clawui-app-nps` | NPS tunneling server | nps |
| **NPC Client** | `clawui-app-npc` | NPS tunneling client | npc |
| **KMS** | `clawui-app-kms` | KMS activation server | py3-kms |
| **FRP** | `clawui-app-frp` | FRP tunneling client | frpc |
| **Transmission** | `clawui-app-transmission` | BitTorrent client | transmission |
| **AdGuard Home** | `clawui-app-adguard` | DNS ad blocker | adguardhome |
| **FTP Server** | `clawui-app-vsftpd` | FTP file server | vsftpd |
| **Samba** | `clawui-app-samba` | File sharing | samba |

## 🚀 Installation

### 1. Install the service (from Alpine repos)

```bash
# Example: Install Aria2
apk add aria2

# Example: Install NPS server
apk add nps

# Example: Install Transmission
apk add transmission
```

### 2. Install the ClawUI management interface

```bash
# Download APK
wget https://github.com/openclaw/clawui-apps/releases/latest/download/clawui-app-aria2-1.0.0-r0_noarch.apk

# Install
apk add --allow-untrusted clawui-app-aria2-1.0.0-r0_noarch.apk
```

### 3. Start the service

```bash
/etc/init.d/aria2 start
rc-update add aria2 default
```

### 4. Access via web browser

```
http://192.168.1.1/app/clawui-app-aria2
```

## 🏗️ Build from Source

```bash
cd clawui/apps

# Build all apps
../scripts/build-managers.sh all

# Build specific app
../scripts/build-managers.sh build clawui-app-aria2

# Output directory
ls ../out/packages/
```

## 📁 Package Structure

```
clawui-app-<name>.apk
├── .PKGINFO
└── usr/
    └── share/
        └── clawui/
            └── apps/
                └── clawui-app-<name>/
                    ├── manifest.json      # App metadata
                    ├── www/
                    │   └── index.html     # Web UI
                    └── api/
                        └── handler.sh     # API endpoints
```

## 🛠️ Development

### Create a new app

1. **Create directory structure:**
```bash
mkdir -p clawui/apps/clawui-app-myapp/{www,api,i18n}
```

2. **Create manifest.json:**
```json
{
  "id": "clawui-app-myapp",
  "name": "MyApp",
  "version": "1.0.0",
  "description": "My app description",
  "icon": "star",
  "category": "tools",
  "dependencies": ["myapp"]
}
```

3. **Create APKBUILD:**
```bash
pkgname=clawui-app-myapp
pkgver=1.0.0
pkgrel=0
pkgdesc="ClawUI web management for myapp"
arch="noarch"
license="MIT"
depends="clawui myapp"

package() {
    mkdir -p "$pkgdir/usr/share/clawui/apps/clawui-app-myapp"
    cp -r "$srcdir"/www/* "$pkgdir/usr/share/clawui/apps/clawui-app-myapp/"
    mkdir -p "$pkgdir/usr/share/clawui/apps/clawui-app-myapp/api"
    cp "$srcdir"/api/handler.sh "$pkgdir/usr/share/clawui/apps/clawui-app-myapp/api/"
    chmod +x "$pkgdir/usr/share/clawui/apps/clawui-app-myapp/api/handler.sh"
    cp "$srcdir"/manifest.json "$pkgdir/usr/share/clawui/apps/clawui-app-myapp/"
}
sha512sums=""
```

4. **Create Web UI (www/index.html)** and **API handler (api/handler.sh)**

5. **Build:**
```bash
../scripts/build-managers.sh build clawui-app-myapp
```

## 📊 Architecture

```
┌─────────────────────────────────────────┐
│         Alpine Linux Official           │
│    aria2  │  nps  │  transmission  │ ... │
└───────────┴───────┴─────────────────┴─────┘
              ↓ (apk install)
┌─────────────────────────────────────────┐
│         Router (AX6600)                 │
│  /usr/bin/aria2c  /etc/init.d/aria2     │
└─────────────────────────────────────────┘
              ↓ (OpenRC service)
┌─────────────────────────────────────────┐
│      ClawUI App (Web Interface)         │
│  clawui-app-aria2                       │
│  - Web UI (HTML/CSS/JS)                 │
│  - API Handler (Shell)                  │
└─────────────────────────────────────────┘
              ↓ (User access)
┌─────────────────────────────────────────┐
│         User Browser                    │
│  http://router-ip/app/clawui-app-aria2  │
└─────────────────────────────────────────┘
```

## 📚 Documentation

- [CLAWUI.md](docs/CLAWUI.md) - ClawUI main interface
- [APPS.md](clawui/APPS.md) - ClawUI app ecosystem
- [NPS-VS-NPC.md](NPS-VS-NPC.md) - NPS server vs NPC client

## 🎯 Use Cases

### Home Lab
- **Aria2/Transmission**: Download files 24/7
- **AdGuard Home**: Block ads network-wide
- **Samba**: Share files with family devices

### Remote Access
- **NPS/NPC**: Access home devices from outside
- **FRP**: Alternative tunneling solution

### Office/Enterprise
- **KMS**: Activate Windows/Office licenses
- **FTP/Samba**: File sharing
- **AdGuard**: DNS filtering

## 📈 Roadmap

- [x] Core apps (Aria2, NPS, NPC, KMS)
- [x] Additional apps (FRP, Transmission, AdGuard, FTP, Samba)
- [ ] App store interface
- [ ] One-click install
- [ ] Auto-update mechanism
- [ ] More apps (Nextcloud, Home Assistant, etc.)

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - See LICENSE file for details.

## 🙏 Acknowledgments

- [Alpine Linux](https://alpinelinux.org/)
- [ClawUI](https://github.com/openclaw/openclaw)
- [JDCloud AX6600](https://github.com/openclaw/ax6600-alpine-clean)

---

**Made with ⚡ for Alpine Linux routers**
