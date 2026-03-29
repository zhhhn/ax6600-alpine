#!/bin/sh
# ClawUI Network Diagnostics App API
# Network diagnostic tools: Ping, Traceroute, DNS, Port Scan

CONF_DIR="/etc/clawui/diag"

# HTTP headers
header() {
    echo "Content-Type: application/json"
    echo ""
}

# Ping test
ping_test() {
    local host=$(echo "$QUERY_STRING" | grep -o 'host=[^&]*' | cut -d= -f2 | urldecode)
    local count=$(echo "$QUERY_STRING" | grep -o 'count=[^&]*' | cut -d= -f2)
    local size=$(echo "$QUERY_STRING" | grep -o 'size=[^&]*' | cut -d= -f2)
    
    host=${host:-"8.8.8.8"}
    count=${count:-4}
    size=${size:-64}
    
    if [ -z "$host" ]; then
        echo '{"success": false, "message": "主机地址必填"}'
        return 1
    fi
    
    # Run ping
    local result=$(ping -c $count -s $size "$host" 2>&1)
    local exit_code=$?
    
    # Parse results
    local packets_tx=$(echo "$result" | grep 'packets transmitted' | awk '{print $1}')
    local packets_rx=$(echo "$result" | grep 'packets transmitted' | awk '{print $4}')
    local packet_loss=$(echo "$result" | grep 'packet loss' | grep -oE '[0-9]+%' | tr -d '%')
    local min=$(echo "$result" | grep 'rtt min/avg/max/mdev' | cut -d= -f2 | awk -F'/' '{print $1}')
    local avg=$(echo "$result" | grep 'rtt min/avg/max/mdev' | cut -d= -f2 | awk -F'/' '{print $2}')
    local max=$(echo "$result" | grep 'rtt min/avg/max/mdev' | cut -d= -f2 | awk -F'/' '{print $3}')
    
    # Get individual ping results
    local icmp_seq=$(echo "$result" | grep 'icmp_seq' | jq -Rs 'split("\n") | map(select(length > 0))')
    
    cat << EOF
{
    "success": $([ $exit_code -eq 0 ] && echo 'true' || echo 'false'),
    "host": "$host",
    "count": $count,
    "packets_transmitted": ${packets_tx:-0},
    "packets_received": ${packets_rx:-0},
    "packet_loss": ${packet_loss:-100},
    "rtt_min": ${min:-0},
    "rtt_avg": ${avg:-0},
    "rtt_max": ${max:-0},
    "results": $icmp_seq
}
EOF
}

# Traceroute test
traceroute_test() {
    local host=$(echo "$QUERY_STRING" | grep -o 'host=[^&]*' | cut -d= -f2 | urldecode)
    local max_hops=$(echo "$QUERY_STRING" | grep -o 'hops=[^&]*' | cut -d= -f2)
    local proto=$(echo "$QUERY_STRING" | grep -o 'proto=[^&]*' | cut -d= -f2)
    
    host=${host:-"8.8.8.8"}
    max_hops=${max_hops:-30}
    proto=${proto:-"udp"}
    
    if [ -z "$host" ]; then
        echo '{"success": false, "message": "主机地址必填"}'
        return 1
    fi
    
    # Run traceroute
    local result
    case "$proto" in
        tcp)
            result=$(traceroute -n -m $max_hops -T "$host" 2>&1)
            ;;
        icmp)
            result=$(traceroute -n -m $max_hops -I "$host" 2>&1)
            ;;
        *)
            result=$(traceroute -n -m $max_hops "$host" 2>&1)
            ;;
    esac
    
    # Parse hops
    local hops="[]"
    local hop_num=0
    echo "$result" | tail -n +2 | while read line; do
        hop_num=$((hop_num + 1))
        
        # Parse line
        local hop_info=$(echo "$line" | awk '{
            hop = $1
            ip = ""
            rtt = ""
            
            for(i=2; i<=NF; i++) {
                if($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                    ip = $i
                }
                if($i ~ /^[0-9]+\.[0-9]+$/ || $i ~ /^\*/ ) {
                    rtt = $i
                }
            }
            
            if(ip == "") ip = "*"
            if(rtt == "") rtt = "0"
            
            printf "{\"hop\": %d, \"ip\": \"%s\", \"rtt\": %s}", hop, ip, rtt
        }')
        
        echo "$hop_info"
    done | jq -s '.'
    
    echo "{\"host\": \"$host\", \"hops\": $(echo "$result" | tail -n +2 | while read line; do echo "$line"; done | jq -Rs 'split("\n") | map(select(length > 0))')}"
}

# DNS lookup test
dns_test() {
    local domain=$(echo "$QUERY_STRING" | grep -o 'domain=[^&]*' | cut -d= -f2 | urldecode)
    local server=$(echo "$QUERY_STRING" | grep -o 'server=[^&]*' | cut -d= -f2 | urldecode)
    local type=$(echo "$QUERY_STRING" | grep -o 'type=[^&]*' | cut -d= -f2)
    
    domain=${domain:-"google.com"}
    type=${type:-"A"}
    
    # Build dig command
    local cmd="dig +short"
    [ -n "$server" ] && cmd="$cmd @$server"
    cmd="$cmd $domain $type"
    
    # Run DNS query
    local result=$(eval $cmd 2>&1)
    local exit_code=$?
    
    # Get DNS server used
    local dns_server=${server:-$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}')}
    
    # Parse results
    local answers=$(echo "$result" | jq -Rs 'split("\n") | map(select(length > 0))')
    
    # Also get full response
    local full=$(dig $domain $type ${server:+@$server} 2>&1 | jq -Rs '.')
    
    cat << EOF
{
    "success": $([ $exit_code -eq 0 ] && echo 'true' || echo 'false'),
    "domain": "$domain",
    "type": "$type",
    "server": "$dns_server",
    "answers": $answers,
    "full_response": $full
}
EOF
}

# Port scan
port_scan() {
    local host=$(echo "$QUERY_STRING" | grep -o 'host=[^&]*' | cut -d= -f2 | urldecode)
    local ports=$(echo "$QUERY_STRING" | grep -o 'ports=[^&]*' | cut -d= -f2 | urldecode)
    local scan_type=$(echo "$QUERY_STRING" | grep -o 'type=[^&]*' | cut -d= -f2)
    
    host=${host:-"localhost"}
    ports=${ports:-"22,80,443,8080"}
    scan_type=${scan_type:-"tcp"}
    
    if [ -z "$host" ]; then
        echo '{"success": false, "message": "主机地址必填"}'
        return 1
    fi
    
    local result
    local open_ports="[]"
    
    # Simple port check using nc
    for port in $(echo "$ports" | tr ',' ' '); do
        if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            open_ports=$(echo "$open_ports" | jq ". + [$port]")
        fi
    done
    
    # Try nmap if available
    if command -v nmap &>/dev/null; then
        local nmap_result=$(nmap -p "$ports" "$host" 2>&1)
        local nmap_open=$(echo "$nmap_result" | grep 'open' | awk '{print $1}' | cut -d'/' -f1 | jq -Rs 'split("\n") | map(select(length > 0) | tonumber)')
        [ "$nmap_open" != "[]" ] && open_ports="$nmap_open"
    fi
    
    cat << EOF
{
    "success": true,
    "host": "$host",
    "ports_scanned": "$ports",
    "open_ports": $open_ports
}
EOF
}

# Network interface info
interface_info() {
    local iface=$(echo "$QUERY_STRING" | grep -o 'iface=[^&]*' | cut -d= -f2)
    
    if [ -n "$iface" ]; then
        # Single interface
        local info=$(ip addr show "$iface" 2>/dev/null)
        local link=$(ip link show "$iface" 2>/dev/null)
        local route=$(ip route show dev "$iface" 2>/dev/null)
        
        cat << EOF
{
    "name": "$iface",
    "link": $(echo "$link" | jq -Rs '.'),
    "addresses": $(echo "$info" | grep 'inet' | jq -Rs 'split("\n") | map(select(length > 0))'),
    "routes": $(echo "$route" | jq -Rs 'split("\n") | map(select(length > 0))')
}
EOF
    else
        # All interfaces
        local ifaces=$(ip link show | grep -E '^[0-9]+:' | awk -F: '{print $2}' | sed 's/ //g')
        local result="["
        local first=1
        
        for iface in $ifaces; do
            [ "$first" = "0" ] && result="$result,"
            first=0
            
            local state=$(ip link show "$iface" | grep -o 'state [^ ]*' | cut -d' ' -f2)
            local mac=$(ip link show "$iface" | grep ether | awk '{print $2}')
            local mtu=$(ip link show "$iface" | grep -o 'mtu [0-9]*' | cut -d' ' -f2)
            local ipv4=$(ip addr show "$iface" | grep 'inet ' | awk '{print $2}')
            
            result="$result{\"name\": \"$iface\", \"state\": \"$state\", \"mac\": \"$mac\", \"mtu\": $mtu, \"ipv4\": \"${ipv4:-}\"}"
        done
        
        result="$result]"
        echo "$result"
    fi
}

# Connectivity check
connectivity_check() {
    local checks="[]"
    
    # Check gateway
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    local gateway_ok="false"
    if [ -n "$gateway" ] && ping -c 1 -W 2 "$gateway" &>/dev/null; then
        gateway_ok="true"
    fi
    checks=$(echo "$checks" | jq ". + [{\"name\": \"gateway\", \"target\": \"$gateway\", \"success\": $gateway_ok}]")
    
    # Check DNS
    local dns_ok="false"
    if nslookup google.com &>/dev/null; then
        dns_ok="true"
    fi
    checks=$(echo "$checks" | jq ". + [{\"name\": \"dns\", \"success\": $dns_ok}]")
    
    # Check Internet
    local internet_ok="false"
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        internet_ok="true"
    fi
    checks=$(echo "$checks" | jq ". + [{\"name\": \"internet\", \"target\": \"8.8.8.8\", \"success\": $internet_ok}]")
    
    # Check HTTPS
    local https_ok="false"
    if curl -s --max-time 5 https://www.google.com &>/dev/null; then
        https_ok="true"
    fi
    checks=$(echo "$checks" | jq ". + [{\"name\": \"https\", \"target\": \"google.com\", \"success\": $https_ok}]")
    
    cat << EOF
{
    "gateway": "$gateway",
    "checks": $checks,
    "overall": $(echo "$checks" | jq '[.[] | select(.success == true)] | length > 0')
}
EOF
}

# Bandwidth test (simple)
bandwidth_test() {
    local server=$(echo "$QUERY_STRING" | grep -o 'server=[^&]*' | cut -d= -f2 | urldecode)
    server=${server:-"speedtest.net"}
    
    # This is a placeholder - real bandwidth testing requires more complex implementation
    cat << EOF
{
    "success": true,
    "message": "Bandwidth test requires speedtest-cli or similar tool",
    "download_speed": null,
    "upload_speed": null,
    "latency": null
}
EOF
}

# WiFi scan
wifi_scan() {
    local iface=$(echo "$QUERY_STRING" | grep -o 'iface=[^&]*' | cut -d= -f2)
    iface=${iface:-"wlan0"}
    
    local results="[]"
    
    if command -v iw &>/dev/null; then
        results=$(iw dev $iface scan 2>/dev/null | jq -Rs '
            split("\n") | 
            map(select(test("BSS|SSID|signal|freq"))) |
            . as $lines |
            [] |
            . as $result |
            $lines | 
            reduce .[] as $item (
                $result;
                if $item | test("^BSS") then
                    . + [{}]
                else
                    .[-1] = (
                        .[-1] + (
                            if $item | test("SSID") then
                                {"ssid": ($item | split(":")[1] | gsub("^\\s+|\\s+$"; ""))}
                            elif $item | test("signal") then
                                {"signal": ($item | split(":")[1] | gsub("^\\s+|\\s+$"; ""))}
                            elif $item | test("freq") then
                                {"freq": ($item | split(":")[1] | gsub("^\\s+|\\s+$"; ""))}
                            else
                                {}
                            end
                        )
                    )
                end
            )
        ')
    fi
    
    echo "{\"interface\": \"$iface\", \"networks\": $results}"
}

# URL decode helper
urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# Route request
header

case "$REQUEST_METHOD" in
    GET)
        case "$PATH_INFO" in
            /api/apps/diag/ping)
                ping_test
                ;;
            /api/apps/diag/traceroute)
                traceroute_test
                ;;
            /api/apps/diag/dns)
                dns_test
                ;;
            /api/apps/diag/portscan)
                port_scan
                ;;
            /api/apps/diag/interface)
                interface_info
                ;;
            /api/apps/diag/connectivity)
                connectivity_check
                ;;
            /api/apps/diag/bandwidth)
                bandwidth_test
                ;;
            /api/apps/diag/wifi)
                wifi_scan
                ;;
            *)
                connectivity_check
                ;;
        esac
        ;;
    *)
        echo '{"error": "Method not allowed"}'
        ;;
esac