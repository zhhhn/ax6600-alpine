#!/bin/sh
# Reboot handler

echo "Content-Type: text/html"
echo ""

# Schedule reboot
reboot &

cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>重启中 - AX6600</title>
    <style>
        body { 
            background: #1a1a2e; color: #eee; font-family: sans-serif;
            text-align: center; padding: 100px 20px;
        }
        .spinner {
            width: 50px; height: 50px; border: 5px solid #333;
            border-top: 5px solid #667eea; border-radius: 50%;
            animation: spin 1s linear infinite; margin: 30px auto;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <h1>🔄 系统正在重启...</h1>
    <div class="spinner"></div>
    <p>请稍候，系统将自动重启</p>
    <p>重启后请重新连接网络</p>
    <script>
        setTimeout(() => {
            window.location.href = '/';
        }, 60000);
    </script>
</body>
</html>
EOF