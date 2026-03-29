# ClawUI App Template
# Use this to create new app packages

APP_NAME=""          # e.g. "openvpn"
APP_TITLE=""         # e.g. "OpenVPN"
APP_ICON=""          # e.g. "vpn", "shield", "download", "settings"
APP_CATEGORY=""      # e.g. "vpn", "download", "network", "system"
DEPENDS_PKG=""       # e.g. "openvpn"
DEPENDS_UI=""        # e.g. "clawui-app-openvpn"

create_app() {
    local name="$1"
    local title="$2"
    
    mkdir -p "apps/$name"/{api,i18n}
    
    # Create manifest
    cat > "apps/$name/manifest.json" << EOF
{
    "id": "$name",
    "name": "$title",
    "version": "1.0.0",
    "author": "",
    "description": "",
    "icon": "app",
    "category": "system",
    "depends": [],
    "provides": ["clawui-app-$name"]
}
EOF
    
    # Create main HTML
    cat > "apps/$name/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{{APP_TITLE}}</title>
    <link rel="stylesheet" href="/css/clawui.css">
</head>
<body>
    <div id="app">
        <h2>{{APP_TITLE}}</h2>
        <div id="content">
            <!-- App content here -->
        </div>
    </div>
    <script src="/js/api.js"></script>
    <script src="app.js"></script>
</body>
</html>
EOF
    
    # Create app JS
    cat > "apps/$name/app.js" << 'EOF'
// App initialization
const APP = {
    name: '{{APP_NAME}}',
    
    init() {
        this.loadStatus();
    },
    
    async loadStatus() {
        const data = await API.get('/api/apps/{{APP_NAME}}/status');
        this.render(data);
    },
    
    render(data) {
        document.getElementById('content').innerHTML = `
            <div class="card">
                <h3>Status</h3>
                <pre>${JSON.stringify(data, null, 2)}</pre>
            </div>
        `;
    }
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => APP.init());
EOF
    
    # Create API script
    cat > "apps/$name/api/status.sh" << 'EOF'
#!/bin/sh
echo "Content-Type: application/json"
echo ""
echo '{"status": "ok"}'
EOF
    
    chmod +x "apps/$name/api/status.sh"
    
    # Create i18n
    cat > "apps/$name/i18n/zh-cn.json" << EOF
{
    "name": "{{APP_TITLE}}",
    "description": "",
    "status": "状态",
    "settings": "设置"
}
EOF
    
    echo "App '$name' created in apps/$name/"
}

# Usage
if [ -n "$1" ]; then
    create_app "$1" "${2:-$1}"
else
    echo "Usage: $0 <app-name> [app-title]"
    echo "Example: $0 openvpn OpenVPN"
fi