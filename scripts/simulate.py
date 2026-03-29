#!/usr/bin/env python3
"""
AX6600 路由器模拟器 - 轻量级 Web UI 模拟
无需 Docker/QEMU，直接运行
"""

import http.server
import socketserver
import json
import os
import subprocess
import urllib.parse
from datetime import datetime

PORT = 8080
PROJ_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class RouterHandler(http.server.SimpleHTTPRequestHandler):
    """路由器 HTTP 处理器"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.join(PROJ_DIR, 'rootfs-overlay', 'www'), **kwargs)
    
    def do_GET(self):
        """处理 GET 请求"""
        parsed = urllib.parse.urlparse(self.path)
        
        if parsed.path == '/api/stats':
            self.handle_stats()
        elif parsed.path == '/api/network':
            self.handle_network()
        elif parsed.path == '/api/wifi':
            self.handle_wifi()
        elif parsed.path == '/api/system':
            self.handle_system()
        elif parsed.path.endswith('.cgi'):
            self.handle_cgi(parsed.path)
        else:
            super().do_GET()
    
    def do_POST(self):
        """处理 POST 请求"""
        parsed = urllib.parse.urlparse(self.path)
        
        if parsed.path == '/api/wifi':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode()
            self.handle_wifi_config(post_data)
        elif parsed.path == '/api/reboot':
            self.handle_reboot()
        else:
            self.send_error(404)
    
    def handle_stats(self):
        """返回系统状态 API"""
        # 模拟数据
        stats = {
            "uptime": self.get_uptime(),
            "cpu": 15,
            "memory": "256MB / 512MB",
            "memory_percent": 50,
            "wan_ip": "192.168.1.100",
            "download": "1.2 GB",
            "upload": "0.8 GB",
            "wifi_2g": "AX6600",
            "wifi_5g": "AX6600-5G",
            "clients": 3,
            "dhcp_list": [
                {"ip": "192.168.1.101", "mac": "AA:BB:CC:DD:EE:01", "hostname": "phone"},
                {"ip": "192.168.1.102", "mac": "AA:BB:CC:DD:EE:02", "hostname": "laptop"},
                {"ip": "192.168.1.103", "mac": "AA:BB:CC:DD:EE:03", "hostname": "tv"},
            ]
        }
        
        self.send_json(stats)
    
    def handle_network(self):
        """返回网络配置"""
        config = {
            "lan_ip": "192.168.1.1",
            "lan_mask": "255.255.255.0",
            "wan_type": "dhcp",
            "wan_ip": "192.168.1.100",
        }
        self.send_json(config)
    
    def handle_wifi(self):
        """返回 WiFi 配置"""
        wifi = {
            "enabled": True,
            "ssid_2g": "AX6600",
            "ssid_5g": "AX6600-5G",
            "channel_2g": 6,
            "channel_5g": 36,
        }
        self.send_json(wifi)
    
    def handle_wifi_config(self, data):
        """处理 WiFi 配置"""
        params = urllib.parse.parse_qs(data)
        
        ssid = params.get('ssid', [''])[0]
        password = params.get('password', [''])[0]
        
        result = {
            "success": True,
            "message": f"WiFi 配置已更新: SSID={ssid}",
        }
        self.send_json(result)
    
    def handle_system(self):
        """返回系统信息"""
        system = {
            "kernel": "6.6.22",
            "alpine": "3.19.0",
            "hostname": "ax6600",
        }
        self.send_json(system)
    
    def handle_reboot(self):
        """处理重启请求"""
        self.send_json({"success": True, "message": "系统正在重启..."})
    
    def handle_cgi(self, path):
        """执行 CGI 脚本"""
        cgi_path = os.path.join(PROJ_DIR, 'rootfs-overlay', 'www', path.lstrip('/'))
        
        if os.path.exists(cgi_path):
            try:
                # 设置环境变量
                env = os.environ.copy()
                env['REQUEST_METHOD'] = 'GET'
                env['QUERY_STRING'] = ''
                
                # 执行脚本
                result = subprocess.run(['bash', cgi_path], capture_output=True, env=env, text=True)
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                self.wfile.write(result.stdout.encode())
            except Exception as e:
                self.send_error(500, str(e))
        else:
            self.send_error(404)
    
    def send_json(self, data):
        """发送 JSON 响应"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())
    
    def get_uptime(self):
        """获取运行时间"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
                hours = int(uptime_seconds // 3600)
                minutes = int((uptime_seconds % 3600) // 60)
                return f"{hours}小时 {minutes}分钟"
        except:
            return "模拟运行时间"
    
    def log_message(self, format, *args):
        """自定义日志格式"""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}")


def main():
    """主入口"""
    print("=" * 50)
    print("  AX6600 路由器模拟器")
    print("=" * 50)
    print()
    print(f"Web UI: http://localhost:{PORT}")
    print()
    print("功能:")
    print("  ✅ 状态 API (/api/stats)")
    print("  ✅ 网络 API (/api/network)")
    print("  ✅ WiFi API (/api/wifi)")
    print("  ✅ 系统 API (/api/system)")
    print("  ✅ 静态文件服务")
    print()
    print("按 Ctrl+C 停止")
    print()
    
    with socketserver.TCPServer(("", PORT), RouterHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n服务器已停止")


if __name__ == '__main__':
    main()