#!/bin/bash
# Docker Router Simulator - 快速路由器模拟环境
# 使用 Docker + Alpine 模拟路由器功能

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINER_NAME="ax6600-router"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 构建 Docker 镜像
build_image() {
    info "构建路由器 Docker 镜像..."
    
    # 创建临时 Dockerfile
    cat > /tmp/Dockerfile.router << 'EOF'
FROM alpine:3.19

# 安装路由器所需软件
RUN apk add --no-cache \
    bash busybox-initscripts openrc \
    iproute2 bridge-utils iptables nftables \
    dnsmasq hostapd wireless-tools \
    lighttpd fcgiwrap \
    dropbear openssh \
    curl wget vim htop \
    procps coreutils

# 创建目录
RUN mkdir -p /var/log/lighttpd /var/lib/misc /run/openrc

# 复制路由器配置和脚本
COPY rootfs-overlay/ /

# 设置权限
RUN chmod +x /usr/sbin/* /etc/init.d/* /www/cgi-bin/* 2>/dev/null || true

# 初始化
RUN touch /run/openrc/softlevel 2>/dev/null || true

# 暴露端口
EXPOSE 80 22 53/udp 53/tcp 67/udp

# 启动命令
CMD ["/sbin/init"]
EOF
    
    docker build -t "$CONTAINER_NAME" -f /tmp/Dockerfile.router "$PROJ_DIR"
    info "✅ 镜像构建完成: $CONTAINER_NAME"
}

# 启动路由器容器
start() {
    info "启动路由器容器..."
    
    # 停止已有容器
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # 启动新容器
    docker run -d \
        --name "$CONTAINER_NAME" \
        --hostname ax6600 \
        --privileged \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_ADMIN \
        -p 8080:80 \
        -p 2222:22 \
        -p 53:53/udp \
        -p 53:53/tcp \
        -p 67:67/udp \
        -v /lib/modules:/lib/modules:ro \
        "$CONTAINER_NAME"
    
    info "✅ 路由器容器已启动"
    echo ""
    echo "访问方式:"
    echo "  Web UI: http://localhost:8080"
    echo "  SSH: ssh root@localhost -p 2222"
    echo "  DNS: 127.0.0.1:53"
    echo ""
    echo "进入容器: docker exec -it $CONTAINER_NAME bash"
}

# 停止容器
stop() {
    info "停止路由器容器..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    info "✅ 已停止"
}

# 进入容器
shell() {
    docker exec -it "$CONTAINER_NAME" bash || \
    docker exec -it "$CONTAINER_NAME" sh
}

# 查看日志
logs() {
    docker logs -f "$CONTAINER_NAME"
}

# 在容器内执行命令
exec_cmd() {
    docker exec "$CONTAINER_NAME" "$@"
}

# 初始化容器内的服务
init_services() {
    info "初始化路由器服务..."
    
    # 在容器内启动服务
    docker exec "$CONTAINER_NAME" sh -c '
        # 创建网络接口
        ip link add br-lan type bridge 2>/dev/null || true
        ip addr add 192.168.1.1/24 dev br-lan 2>/dev/null || true
        ip link set br-lan up
        
        # 启动 dnsmasq
        dnsmasq --no-daemon --interface=br-lan --dhcp-range=192.168.1.100,192.168.1.200 &
        
        # 启动 lighttpd
        lighttpd -f /etc/lighttpd/lighttpd.conf -D &
        
        # 启动 dropbear
        dropbear -R -E -F &
        
        echo "Services started"
    '
    
    info "✅ 服务已启动"
}

# 状态
status() {
    echo "=== AX6600 路由器状态 ==="
    echo ""
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo "状态: 运行中"
        echo ""
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "访问方式:"
        echo "  Web UI: http://localhost:8080"
        echo "  SSH: ssh root@localhost -p 2222"
    else
        echo "状态: 未运行"
    fi
}

# 测试 Web UI
test_web() {
    info "测试 Web UI..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        echo "✅ Web UI 正常 (HTTP $response)"
    else
        echo "❌ Web UI 异常 (HTTP $response)"
    fi
}

# 使用帮助
usage() {
    echo "AX6600 Docker 路由器模拟器"
    echo ""
    echo "用法: $0 <命令>"
    echo ""
    echo "命令:"
    echo "  build     构建 Docker 镜像"
    echo "  start     启动路由器"
    echo "  stop      停止路由器"
    echo "  restart   重启路由器"
    echo "  shell     进入容器 shell"
    echo "  logs      查看日志"
    echo "  status    显示状态"
    echo "  init      初始化服务"
    echo "  test      测试服务"
    echo ""
    echo "端口映射:"
    echo "  8080 -> 80  (Web UI)"
    echo "  2222 -> 22  (SSH)"
    echo "  53    -> 53 (DNS)"
    echo "  67    -> 67 (DHCP)"
}

# 主入口
case "${1:-}" in
    build) build_image ;;
    start) start ;;
    stop) stop ;;
    restart) stop; start ;;
    shell) shell ;;
    logs) logs ;;
    status) status ;;
    init) init_services ;;
    test) test_web ;;
    *) usage ;;
esac