#!/bin/bash
# Docker-based test environment for AX6600 firmware
# Provides quick user-space testing without QEMU

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_IMAGE="ax6600-test"

# Build Docker test image
build_image() {
    echo "Building Docker test image..."
    
    cat > /tmp/Dockerfile.ax6600 << 'EOF'
FROM alpine:3.19

# Install test dependencies
RUN apk add --no-cache \
    bash coreutils grep sed gawk \
    curl wget iproute2 bridge-utils \
    nftables iptables \
    openrc busybox-initscripts \
    lighttpd fcgiwrap \
    procps htop vim \
    qemu-aarch64

# Create test directories
RUN mkdir -p /test/rootfs /test/results /var/log/lighttpd

WORKDIR /test

ENTRYPOINT ["/bin/bash"]
EOF
    
    docker build -t "$DOCKER_IMAGE" -f /tmp/Dockerfile.ax6600 /tmp
    echo "✅ Docker image built: $DOCKER_IMAGE"
}

# Run tests in container
run_in_container() {
    local test_cmd="$1"
    
    docker run --rm \
        -v "${PROJ_DIR}/rootfs-overlay:/test/rootfs:ro" \
        -v "${PROJ_DIR}/scripts:/test/scripts:ro" \
        -v "${PROJ_DIR}/test-results:/test/results" \
        --privileged \
        "$DOCKER_IMAGE" \
        -c "$test_cmd"
}

# Test script functionality
test_script_functionality() {
    echo "=== Testing Script Functionality ==="
    
    run_in_container '
        set -e
        
        # Copy scripts to proper locations
        cp -r /test/rootfs/usr/sbin/* /usr/sbin/ 2>/dev/null || true
        cp -r /test/rootfs/etc/* /etc/ 2>/dev/null || true
        
        # Make executable
        chmod +x /usr/sbin/* 2>/dev/null || true
        
        # Test wifi command
        echo "Testing wifi..."
        /usr/sbin/wifi --help && echo "✅ wifi: OK" || echo "❌ wifi: FAIL"
        
        # Test port-forward
        echo "Testing port-forward..."
        /usr/sbin/port-forward list && echo "✅ port-forward: OK" || echo "❌ port-forward: FAIL"
        
        # Test qos
        echo "Testing qos..."
        /usr/sbin/qos status && echo "✅ qos: OK" || echo "❌ qos: FAIL"
        
        # Test factory-reset
        echo "Testing factory-reset..."
        /usr/sbin/factory-reset --dry-run && echo "✅ factory-reset: OK" || echo "❌ factory-reset: FAIL"
        
        echo "Done!"
    '
}

# Test CGI scripts
test_cgi() {
    echo "=== Testing CGI Scripts ==="
    
    run_in_container '
        set -e
        
        # Setup CGI environment
        mkdir -p /www/cgi-bin
        cp /test/rootfs/www/cgi-bin/* /www/cgi-bin/ 2>/dev/null || true
        cp /test/rootfs/www/*.html /www/ 2>/dev/null || true
        cp /test/rootfs/www/*.css /www/ 2>/dev/null || true
        chmod +x /www/cgi-bin/*
        
        # Test each CGI
        export REQUEST_METHOD=GET
        export QUERY_STRING=""
        
        for cgi in /www/cgi-bin/*.cgi; do
            if [ -f "$cgi" ]; then
                name=$(basename "$cgi")
                output=$("$cgi" 2>&1)
                if echo "$output" | grep -q "Content-Type"; then
                    echo "✅ $name"
                else
                    echo "❌ $name"
                fi
            fi
        done
    '
}

# Test network simulation
test_network() {
    echo "=== Testing Network Configuration ==="
    
    run_in_container '
        set -e
        
        # Create dummy interfaces for testing
        ip link add eth0 type dummy 2>/dev/null || true
        ip link add eth1 type dummy 2>/dev/null || true
        ip link add br-lan type bridge 2>/dev/null || true
        
        # Test bridge setup
        ip link set br-lan up
        ip link set eth1 master br-lan 2>/dev/null || true
        
        echo "✅ Network simulation OK"
        
        # Show interfaces
        ip link show
    '
}

# Start interactive shell
interactive() {
    echo "Starting interactive test shell..."
    
    docker run --rm -it \
        -v "${PROJ_DIR}/rootfs-overlay:/test/rootfs" \
        -v "${PROJ_DIR}/scripts:/test/scripts" \
        --privileged \
        "$DOCKER_IMAGE"
}

# Run all tests
all_tests() {
    build_image
    test_script_functionality
    test_cgi
    test_network
    echo ""
    echo "✅ All tests completed!"
}

# Usage
usage() {
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  build     - Build Docker test image"
    echo "  scripts   - Test script functionality"
    echo "  cgi       - Test CGI scripts"
    echo "  network   - Test network configuration"
    echo "  all       - Run all tests"
    echo "  shell     - Interactive shell"
}

# Main
case "${1:-}" in
    build) build_image ;;
    scripts) build_image && test_script_functionality ;;
    cgi) build_image && test_cgi ;;
    network) build_image && test_network ;;
    all) all_tests ;;
    shell) build_image && interactive ;;
    *) usage ;;
esac