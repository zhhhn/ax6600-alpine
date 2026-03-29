#!/bin/sh
# Download NPS client binary for aarch64

set -e

NPS_VERSION="0.26.10"
ARCH="linux_arm64"
DOWNLOAD_URL="https://github.com/ehang-io/nps/releases/download/v${NPS_VERSION}/npc_${NPS_VERSION}_${ARCH}.tar.gz"
INSTALL_DIR="/usr/share/nps"

echo "Downloading NPS client v${NPS_VERSION}..."

mkdir -p "$INSTALL_DIR"
cd /tmp

wget -q "$DOWNLOAD_URL" -O npc.tar.gz
tar -xzf npc.tar.gz
cp npc "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/npc"

rm -f npc npc.tar.gz

echo "NPS client installed to $INSTALL_DIR/npc"
