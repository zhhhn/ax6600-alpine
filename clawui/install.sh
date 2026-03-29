#!/bin/sh
# Install ClawUI
# Run this script on Alpine Linux

set -e

INSTALL_DIR="/usr/share/clawui"
CONFIG_DIR="/etc/clawui"

echo "====================================="
echo "ClawUI Installer"
echo "====================================="
echo ""

# Check root
if [ "$(id -u)" != "0" ]; then
    echo "Please run as root"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
apk add --no-cache bash busybox-extras 2>/dev/null || true

# Create directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR/www/cgi-bin"
mkdir -p "$INSTALL_DIR/www/css"
mkdir -p "$INSTALL_DIR/www/js"
mkdir -p "$INSTALL_DIR/api"
mkdir -p "$CONFIG_DIR"

# Copy files
echo "Installing files..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Web files
cp "$SCRIPT_DIR/www/index.html" "$INSTALL_DIR/www/" 2>/dev/null || true
cp "$SCRIPT_DIR/www/css/clawui.css" "$INSTALL_DIR/www/css/" 2>/dev/null || true
cp "$SCRIPT_DIR/www/js/api.js" "$INSTALL_DIR/www/js/" 2>/dev/null || true
cp "$SCRIPT_DIR/www/js/app.js" "$INSTALL_DIR/www/js/" 2>/dev/null || true
cp "$SCRIPT_DIR/www/cgi-bin/api" "$INSTALL_DIR/www/cgi-bin/" 2>/dev/null || true

# API files
cp "$SCRIPT_DIR/api"/*.sh "$INSTALL_DIR/api/" 2>/dev/null || true

# Config files
cp "$SCRIPT_DIR/../etc/clawui/config" "$CONFIG_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/../etc/clawui/httpd.conf" "$CONFIG_DIR/" 2>/dev/null || true

# Executable
cp "$SCRIPT_DIR/../usr/sbin/clawui" /usr/sbin/ 2>/dev/null || true
chmod +x /usr/sbin/clawui

# Init script
cp "$SCRIPT_DIR/../etc/init.d/clawui" /etc/init.d/ 2>/dev/null || true
chmod +x /etc/init.d/clawui

# Set permissions
chmod +x "$INSTALL_DIR/www/cgi-bin/api"
chmod +x "$INSTALL_DIR/api"/*.sh 2>/dev/null || true

echo ""
echo "====================================="
echo "Installation complete!"
echo "====================================="
echo ""
echo "Start ClawUI:"
echo "  rc-service clawui start"
echo ""
echo "Access:"
echo "  http://$(hostname)"
echo ""
echo "Enable on boot:"
echo "  rc-update add clawui default"
echo ""