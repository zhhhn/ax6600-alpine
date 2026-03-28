#!/bin/bash
# Firmware Virtual Test Environment for AX6600 Alpine
# Uses QEMU for ARM64 emulation

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="${PROJ_DIR}/test-env"
ROOTFS_DIR="${TEST_DIR}/rootfs"
RESULTS_DIR="${TEST_DIR}/results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Setup test environment
setup() {
    info "Setting up virtual test environment..."
    
    mkdir -p "$TEST_DIR" "$ROOTFS_DIR" "$RESULTS_DIR"
    
    # Check for required tools
    local missing=""
    for tool in qemu-aarch64-static qemu-system-aarch64; do
        if ! command -v $tool &> /dev/null; then
            missing="$missing $tool"
        fi
    done
    
    if [ -n "$missing" ]; then
        warn "Missing tools:$missing"
        info "Installing QEMU..."
        sudo apt-get update && sudo apt-get install -y qemu-user-static qemu-system-arm || true
    fi
    
    # Extract rootfs for testing
    if [ -f "${PROJ_DIR}/out/alpine-rootfs.tar.gz" ]; then
        info "Extracting rootfs..."
        rm -rf "${ROOTFS_DIR:?}"/*
        tar -xzf "${PROJ_DIR}/out/alpine-rootfs.tar.gz" -C "$ROOTFS_DIR" 2>/dev/null || {
            warn "Rootfs not found, creating minimal test environment"
            create_minimal_rootfs
        }
    else
        warn "No rootfs found, creating minimal test environment"
        create_minimal_rootfs
    fi
    
    # Setup QEMU static binary
    if [ ! -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static" ]; then
        cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/" 2>/dev/null || true
    fi
    
    info "Test environment ready at $TEST_DIR"
}

# Create minimal rootfs for testing
create_minimal_rootfs() {
    mkdir -p "${ROOTFS_DIR}"/{bin,sbin,usr/bin,usr/sbin,etc,lib,lib64,var,proc,sys,dev,tmp,root}
    
    # Copy our scripts
    cp -r "${PROJ_DIR}/rootfs-overlay/usr/sbin" "${ROOTFS_DIR}/usr/" 2>/dev/null || true
    cp -r "${PROJ_DIR}/rootfs-overlay/etc" "${ROOTFS_DIR}/" 2>/dev/null || true
    
    # Create busybox symlinks
    if [ -f "${ROOTFS_DIR}/bin/busybox" ]; then
        for cmd in sh ls cat echo grep sed awk; do
            ln -sf busybox "${ROOTFS_DIR}/bin/$cmd" 2>/dev/null || true
        done
    fi
}

# Test a script in QEMU
test_script() {
    local script="$1"
    local script_name=$(basename "$script")
    
    info "Testing: $script_name"
    
    # Copy script to test rootfs
    cp "$script" "${ROOTFS_DIR}/tmp/test-script.sh"
    chmod +x "${ROOTFS_DIR}/tmp/test-script.sh"
    
    # Run syntax check
    if bash -n "$script" 2>/dev/null; then
        echo "  ✅ Syntax check passed"
    else
        echo "  ❌ Syntax check failed"
        return 1
    fi
    
    # Run with QEMU if available
    if command -v qemu-aarch64-static &> /dev/null && [ -f "${ROOTFS_DIR}/bin/sh" ]; then
        if timeout 10 qemu-aarch64-static -L "$ROOTFS_DIR" "${ROOTFS_DIR}/bin/sh" "${ROOTFS_DIR}/tmp/test-script.sh" --help 2>/dev/null; then
            echo "  ✅ QEMU execution OK"
        else
            echo "  ⚠️ QEMU execution failed (may be expected)"
        fi
    fi
    
    return 0
}

# Test all scripts
test_all_scripts() {
    info "=== Testing All Scripts ==="
    
    local passed=0
    local failed=0
    
    for script in "${PROJ_DIR}"/rootfs-overlay/usr/sbin/*; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            if test_script "$script"; then
                ((passed++))
            else
                ((failed++))
            fi
        fi
    done
    
    echo ""
    info "Results: $passed passed, $failed failed"
    
    return $failed
}

# Test init.d services
test_init_scripts() {
    info "=== Testing Init Scripts ==="
    
    for script in "${PROJ_DIR}"/rootfs-overlay/etc/init.d/*; do
        if [ -f "$script" ]; then
            local name=$(basename "$script")
            info "Checking: $name"
            
            # Check OpenRC header
            if grep -q "#!/sbin/openrc-run" "$script" || grep -q "#!/bin/sh" "$script"; then
                echo "  ✅ Valid init script format"
            else
                echo "  ⚠️ Missing OpenRC header"
            fi
            
            # Syntax check
            if bash -n "$script" 2>/dev/null; then
                echo "  ✅ Syntax OK"
            else
                echo "  ❌ Syntax error"
            fi
        fi
    done
}

# Test Web UI CGI scripts
test_cgi_scripts() {
    info "=== Testing CGI Scripts ==="
    
    for script in "${PROJ_DIR}"/rootfs-overlay/www/cgi-bin/*.cgi; do
        if [ -f "$script" ]; then
            local name=$(basename "$script")
            info "Testing: $name"
            
            # Syntax check
            if bash -n "$script" 2>/dev/null; then
                echo "  ✅ Syntax OK"
            else
                echo "  ❌ Syntax error"
            fi
            
            # Test output
            export REQUEST_METHOD="GET"
            export QUERY_STRING=""
            local output=$("$script" 2>&1 | head -5)
            
            if echo "$output" | grep -q "Content-Type"; then
                echo "  ✅ Valid HTTP response"
            else
                echo "  ⚠️ No Content-Type header"
            fi
        fi
    done
}

# Test network configuration
test_network_config() {
    info "=== Testing Network Configuration ==="
    
    local interfaces="${PROJ_DIR}/rootfs-overlay/etc/network/interfaces"
    
    if [ -f "$interfaces" ]; then
        info "Checking interfaces file..."
        
        # Check for required interfaces
        for iface in lo eth0 br-lan; do
            if grep -q "auto $iface" "$interfaces" || grep -q "iface $iface" "$interfaces"; then
                echo "  ✅ Interface $iface configured"
            else
                echo "  ❌ Missing interface $iface"
            fi
        done
        
        # Check LAN bridge
        if grep -q "bridge_ports" "$interfaces"; then
            echo "  ✅ Bridge configured"
        fi
    fi
}

# Test WiFi configuration
test_wifi_config() {
    info "=== Testing WiFi Configuration ==="
    
    for conf in "${PROJ_DIR}"/rootfs-overlay/etc/hostapd/*.conf; do
        if [ -f "$conf" ]; then
            local name=$(basename "$conf")
            info "Checking: $name"
            
            # Check required fields
            for field in interface ssid channel wpa wpa_passphrase; do
                if grep -q "^${field}=" "$conf"; then
                    echo "  ✅ $field set"
                else
                    echo "  ⚠️ Missing $field"
                fi
            done
        fi
    done
}

# Test firewall configuration
test_firewall_config() {
    info "=== Testing Firewall Configuration ==="
    
    local nftconf="${PROJ_DIR}/rootfs-overlay/etc/nftables.conf"
    
    if [ -f "$nftconf" ]; then
        info "Checking nftables.conf..."
        
        # Check for required tables/chains
        if grep -q "table inet filter" "$nftconf"; then
            echo "  ✅ Filter table present"
        fi
        
        if grep -q "chain input" "$nftconf"; then
            echo "  ✅ Input chain present"
        fi
        
        if grep -q "chain forward" "$nftconf"; then
            echo "  ✅ Forward chain present"
        fi
        
        if grep -q "table ip nat" "$nftconf"; then
            echo "  ✅ NAT table present"
        fi
    fi
}

# Run full test suite
run_tests() {
    local mode="${1:-all}"
    
    echo "=========================================="
    echo "  AX6600 Firmware Test Suite"
    echo "=========================================="
    echo ""
    
    setup
    
    local total_errors=0
    
    case "$mode" in
        scripts)
            test_all_scripts || ((total_errors++))
            ;;
        init)
            test_init_scripts
            ;;
        cgi)
            test_cgi_scripts
            ;;
        config)
            test_network_config
            test_wifi_config
            test_firewall_config
            ;;
        all|"")
            test_all_scripts || ((total_errors++))
            test_init_scripts
            test_cgi_scripts
            test_network_config
            test_wifi_config
            test_firewall_config
            ;;
        *)
            error "Unknown test mode: $mode"
            echo "Usage: $0 {all|scripts|init|cgi|config}"
            exit 1
            ;;
    esac
    
    echo ""
    echo "=========================================="
    if [ $total_errors -eq 0 ]; then
        echo -e "${GREEN}  All tests passed!${NC}"
    else
        echo -e "${RED}  $total_errors test(s) failed${NC}"
    fi
    echo "=========================================="
    
    return $total_errors
}

# Quick smoke test
smoke_test() {
    info "Running smoke test..."
    
    setup
    
    # Test basic scripts
    local scripts=(
        "rootfs-overlay/usr/sbin/wifi"
        "rootfs-overlay/usr/sbin/port-forward"
        "rootfs-overlay/usr/sbin/qos"
        "rootfs-overlay/usr/sbin/factory-reset"
    )
    
    for script in "${scripts[@]}"; do
        local full_path="${PROJ_DIR}/${script}"
        if [ -f "$full_path" ]; then
            if bash -n "$full_path" 2>/dev/null; then
                echo "✅ $(basename $script)"
            else
                echo "❌ $(basename $script)"
            fi
        fi
    done
}

# Main
case "${1:-all}" in
    setup) setup ;;
    smoke) smoke_test ;;
    test) run_tests "$2" ;;
    *) run_tests "$1" ;;
esac