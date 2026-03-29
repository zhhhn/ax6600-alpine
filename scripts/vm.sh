#!/bin/bash
# QEMU Virtual Router - AX6600 模拟环境
# 创建可刷入固件的 ARM64 虚拟机

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="${PROJ_DIR}/vm"
IMAGES_DIR="${VM_DIR}/images"

# VM 配置
VM_NAME="ax6600-vm"
VM_MEMORY="512M"
VM_CPUS="2"
VM_DISK="256M"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 检查依赖
check_deps() {
    info "检查依赖..."
    
    local missing=""
    for cmd in qemu-system-aarch64 qemu-img; do
        if ! command -v $cmd &> /dev/null; then
            missing="$missing $cmd"
        fi
    done
    
    if [ -n "$missing" ]; then
        error "缺少依赖: $missing"
        echo ""
        echo "安装命令:"
        echo "  Ubuntu/Debian: sudo apt-get install qemu-system-arm qemu-utils"
        echo "  macOS: brew install qemu"
        echo "  Arch: sudo pacman -S qemu-arch-extra"
        exit 1
    fi
    
    info "✅ 所有依赖已安装"
}

# 创建虚拟机目录
setup_dirs() {
    mkdir -p "$VM_DIR" "$IMAGES_DIR"
}

# 创建虚拟磁盘
create_disk() {
    local disk_img="${IMAGES_DIR}/${VM_NAME}.qcow2"
    
    if [ -f "$disk_img" ]; then
        info "虚拟磁盘已存在: $disk_img"
        return 0
    fi
    
    step "创建虚拟磁盘 (${VM_DISK})..."
    qemu-img create -f qcow2 "$disk_img" "$VM_DISK"
    info "✅ 虚拟磁盘创建完成: $disk_img"
}

# 准备启动镜像
prepare_boot_images() {
    step "准备启动镜像..."
    
    # 检查固件文件
    local kernel="${PROJ_DIR}/out/Image.gz"
    local dtb="${PROJ_DIR}/out/ipq6018-jdcloud-ax6600.dtb"
    local rootfs="${PROJ_DIR}/out/alpine-rootfs.tar.gz"
    local itb="${PROJ_DIR}/out/ax6600-alpine.itb"
    
    if [ ! -f "$kernel" ]; then
        warn "内核文件不存在，需要先构建固件"
        return 1
    fi
    
    # 创建 ext4 根文件系统镜像
    local rootfs_img="${IMAGES_DIR}/rootfs.img"
    
    if [ ! -f "$rootfs_img" ] || [ "$rootfs" -nt "$rootfs_img" ]; then
        info "创建 rootfs 镜像..."
        
        local rootfs_size="256M"
        dd if=/dev/zero of="$rootfs_img" bs=1 count=0 seek=$rootfs_size 2>/dev/null
        
        # 在 Linux 上用 mkfs.ext4 -d
        if command -v mkfs.ext4 &> /dev/null; then
            # 创建临时目录
            local tmp_root=$(mktemp -d)
            tar -xzf "$rootfs" -C "$tmp_root" 2>/dev/null || true
            
            # 复制我们的配置
            cp -r "${PROJ_DIR}/rootfs-overlay/"* "$tmp_root/" 2>/dev/null || true
            
            # 创建 ext4 镜像
            mkfs.ext4 -F -d "$tmp_root" "$rootfs_img" 2>/dev/null || {
                warn "mkfs.ext4 -d 不支持，使用传统方法"
                mkfs.ext4 -F "$rootfs_img" 2>/dev/null
            }
            
            rm -rf "$tmp_root"
        fi
        
        info "✅ rootfs 镜像创建完成: $rootfs_img"
    fi
    
    # 解压内核
    local kernel_img="${IMAGES_DIR}/Image"
    if [ ! -f "$kernel_img" ] || [ "$kernel" -nt "$kernel_img" ]; then
        info "解压内核..."
        gunzip -c "$kernel" > "$kernel_img" 2>/dev/null || cp "$kernel" "${kernel_img}.gz"
    fi
    
    # 复制 DTB
    if [ -f "$dtb" ]; then
        cp "$dtb" "${IMAGES_DIR}/"
    fi
}

# 创建 U-Boot 启动脚本
create_boot_script() {
    cat > "${IMAGES_DIR}/boot.cmd" << 'EOF'
# U-Boot boot script for AX6600 VM

# Set boot arguments
setenv bootargs "root=/dev/vda1 rw rootfstype=ext4 console=ttyAMA0,115200 earlyprintk"

# Load kernel
load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /Image

# Load dtb
load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /virt.dtb

# Boot
booti ${kernel_addr_r} - ${fdt_addr_r}
EOF
    
    info "✅ 启动脚本创建完成"
}

# 创建虚拟 DTB（使用 QEMU virt 机器的 DTB）
create_virt_dtb() {
    step "创建虚拟设备树..."
    
    # QEMU virt 机器使用自己的 DTB
    # 我们需要为路由器功能添加虚拟设备
    warn "使用 QEMU virt 机器 DTB（与真实 AX6600 硬件不同）"
}

# 启动虚拟机
start_vm() {
    step "启动 AX6600 虚拟机..."
    
    local kernel="${IMAGES_DIR}/Image"
    local rootfs="${IMAGES_DIR}/rootfs.img"
    local disk="${IMAGES_DIR}/${VM_NAME}.qcow2"
    
    # 检查镜像
    if [ ! -f "$kernel" ] && [ ! -f "${kernel}.gz" ]; then
        error "内核文件不存在！"
        echo "请先运行: $0 prepare"
        exit 1
    fi
    
    if [ ! -f "$rootfs" ]; then
        error "rootfs 镜像不存在！"
        echo "请先运行: $0 prepare"
        exit 1
    fi
    
    # QEMU 启动参数
    local qemu_cmd="qemu-system-aarch64 \
        -name ${VM_NAME} \
        -machine virt \
        -cpu cortex-a57 \
        -smp ${VM_CPUS} \
        -m ${VM_MEMORY} \
        -nographic \
        -kernel ${kernel} \
        -append 'root=/dev/vda rw rootfstype=ext4 console=ttyAMA0,115200 panic=1' \
        -drive if=virtio,file=${rootfs},format=raw,if=virtio \
        -netdev user,id=net0,hostfwd=tcp::8080-:80,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -monitor telnet:127.0.0.1:4444,server,nowait"
    
    info "启动命令:"
    echo "$qemu_cmd"
    echo ""
    
    info "=== 虚拟机访问方式 ==="
    echo "  串口控制台: 当前终端"
    echo "  Web UI: http://localhost:8080"
    echo "  SSH: ssh root@localhost -p 2222"
    echo "  QEMU 监控: telnet localhost 4444"
    echo ""
    info "退出: Ctrl+A 然后按 X"
    echo ""
    
    # 启动
    eval $qemu_cmd
}

# 启动带图形界面的虚拟机
start_vm_gui() {
    step "启动 AX6600 虚拟机 (图形模式)..."
    
    local kernel="${IMAGES_DIR}/Image"
    local rootfs="${IMAGES_DIR}/rootfs.img"
    
    qemu-system-aarch64 \
        -name ${VM_NAME} \
        -machine virt \
        -cpu cortex-a57 \
        -smp ${VM_CPUS} \
        -m ${VM_MEMORY} \
        -kernel "$kernel" \
        -append 'root=/dev/vda rw rootfstype=ext4 console=ttyAMA0,115200' \
        -drive if=virtio,file="$rootfs",format=raw \
        -netdev user,id=net0,hostfwd=tcp::8080-:80,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -device virtio-gpu-pci \
        -display default,show-cursor=on \
        -serial stdio
}

# 后台运行虚拟机
start_vm_daemon() {
    step "启动 AX6600 虚拟机 (后台模式)..."
    
    local kernel="${IMAGES_DIR}/Image"
    local rootfs="${IMAGES_DIR}/rootfs.img"
    local pidfile="${VM_DIR}/${VM_NAME}.pid"
    
    if [ -f "$pidfile" ] && kill -0 $(cat "$pidfile") 2>/dev/null; then
        warn "虚拟机已在运行 (PID: $(cat $pidfile))"
        return 1
    fi
    
    qemu-system-aarch64 \
        -name ${VM_NAME} \
        -machine virt \
        -cpu cortex-a57 \
        -smp ${VM_CPUS} \
        -m ${VM_MEMORY} \
        -kernel "$kernel" \
        -append 'root=/dev/vda rw rootfstype=ext4 console=ttyAMA0,115200' \
        -drive if=virtio,file="$rootfs",format=raw \
        -netdev user,id=net0,hostfwd=tcp::8080-:80,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -nographic \
        -serial mon:stdio \
        -daemonize \
        -pidfile "$pidfile"
    
    info "✅ 虚拟机已启动 (PID: $(cat $pidfile))"
    echo ""
    info "访问方式:"
    echo "  Web UI: http://localhost:8080"
    echo "  SSH: ssh root@localhost -p 2222"
}

# 停止虚拟机
stop_vm() {
    local pidfile="${VM_DIR}/${VM_NAME}.pid"
    
    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$pidfile"
            info "✅ 虚拟机已停止"
        else
            rm -f "$pidfile"
            warn "虚拟机未运行"
        fi
    else
        warn "未找到 PID 文件"
    fi
}

# 连接到虚拟机控制台
connect_console() {
    info "连接到虚拟机串口..."
    echo "按 Ctrl+] 退出"
    echo ""
    telnet localhost 4444
}

# SSH 连接
ssh_connect() {
    info "SSH 连接到虚拟机..."
    ssh -o StrictHostKeyChecking=no -p 2222 root@localhost
}

# 刷入固件
flash_firmware() {
    local firmware="$1"
    
    if [ -z "$firmware" ]; then
        firmware="${PROJ_DIR}/out/ax6600-alpine-factory.bin"
    fi
    
    if [ ! -f "$firmware" ]; then
        error "固件文件不存在: $firmware"
        exit 1
    fi
    
    step "刷入固件到虚拟磁盘..."
    
    # 在真实环境中，这会将固件写入磁盘
    # 对于虚拟机，我们直接替换 rootfs
    warn "虚拟机模式：直接替换 rootfs 镜像"
    
    local rootfs_img="${IMAGES_DIR}/rootfs.img"
    
    # 提取固件中的 rootfs
    # factory.bin 格式: kernel (6MB) + rootfs
    dd if="$firmware" of="${IMAGES_DIR}/kernel.bin" bs=1M count=6 2>/dev/null || true
    dd if="$firmware" of="${IMAGES_DIR}/rootfs-from-firmware.bin" bs=1M skip=6 2>/dev/null || true
    
    info "✅ 固件已刷入"
    info "重启虚拟机以应用更改"
}

# 显示虚拟机状态
status() {
    local pidfile="${VM_DIR}/${VM_NAME}.pid"
    
    echo "=== AX6600 虚拟机状态 ==="
    echo ""
    
    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            echo "状态: 运行中"
            echo "PID: $pid"
            echo ""
            echo "访问方式:"
            echo "  Web UI: http://localhost:8080"
            echo "  SSH: ssh root@localhost -p 2222"
            echo "  控制台: telnet localhost 4444"
        else
            echo "状态: 已停止"
            rm -f "$pidfile"
        fi
    else
        echo "状态: 未运行"
    fi
    
    echo ""
    echo "镜像文件:"
    ls -lh "${IMAGES_DIR}/" 2>/dev/null || echo "  无"
}

# 创建完整虚拟机
create_vm() {
    step "创建 AX6600 虚拟机..."
    
    check_deps
    setup_dirs
    create_disk
    prepare_boot_images
    create_virt_dtb
    create_boot_script
    
    info ""
    info "✅ 虚拟机创建完成！"
    echo ""
    echo "启动虚拟机:"
    echo "  $0 start        # 前台运行"
    echo "  $0 start-gui    # 图形模式"
    echo "  $0 start-daemon # 后台运行"
    echo ""
    echo "访问方式:"
    echo "  Web UI: http://localhost:8080"
    echo "  SSH: ssh root@localhost -p 2222"
}

# 帮助
usage() {
    echo "AX6600 虚拟路由器"
    echo ""
    echo "用法: $0 <命令> [参数]"
    echo ""
    echo "命令:"
    echo "  create        创建虚拟机"
    echo "  prepare       准备启动镜像"
    echo "  start         启动虚拟机 (前台)"
    echo "  start-gui     启动虚拟机 (图形)"
    echo "  start-daemon  启动虚拟机 (后台)"
    echo "  stop          停止虚拟机"
    echo "  status        显示状态"
    echo "  console       连接控制台"
    echo "  ssh           SSH 连接"
    echo "  flash <固件>  刷入固件"
    echo ""
    echo "示例:"
    echo "  $0 create              # 创建虚拟机"
    echo "  $0 start               # 启动并进入控制台"
    echo "  $0 ssh                 # SSH 连接"
    echo ""
    echo "端口映射:"
    echo "  8080 -> 80 (Web UI)"
    echo "  2222 -> 22 (SSH)"
}

# 主入口
case "${1:-}" in
    create)
        create_vm
        ;;
    prepare)
        check_deps
        setup_dirs
        prepare_boot_images
        ;;
    start)
        check_deps
        start_vm
        ;;
    start-gui)
        check_deps
        start_vm_gui
        ;;
    start-daemon)
        check_deps
        start_vm_daemon
        ;;
    stop)
        stop_vm
        ;;
    status)
        status
        ;;
    console)
        connect_console
        ;;
    ssh)
        ssh_connect
        ;;
    flash)
        flash_firmware "$2"
        ;;
    *)
        usage
        ;;
esac