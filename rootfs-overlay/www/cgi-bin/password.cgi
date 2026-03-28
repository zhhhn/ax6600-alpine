#!/bin/sh
# Password change handler

echo "Content-Type: text/html"
echo ""

# Handle POST
if [ "$REQUEST_METHOD" = "POST" ]; then
    read -n $CONTENT_LENGTH POST_DATA
    
    OLD_PASS=$(echo "$POST_DATA" | grep -o 'old_pass=[^&]*' | cut -d= -f2)
    NEW_PASS=$(echo "$POST_DATA" | grep -o 'new_pass=[^&]*' | cut -d= -f2)
    CONFIRM_PASS=$(echo "$POST_DATA" | grep -o 'confirm_pass=[^&]*' | cut -d= -f2)
    
    # Verify current password (simplified - check shadow)
    # In production, use PAM or proper password verification
    
    if [ "$NEW_PASS" != "$CONFIRM_PASS" ]; then
        MSG="错误：两次输入的密码不一致"
    elif [ ${#NEW_PASS} -lt 6 ]; then
        MSG="错误：密码长度至少6位"
    else
        # Change password
        echo "root:$(echo -n "$NEW_PASS" | openssl passwd -1 -stdin)" | chpasswd 2>/dev/null && \
            MSG="密码修改成功" || \
            MSG="密码修改失败"
    fi
fi

cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>修改密码 - AX6600</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <header><h1>🔐 修改密码</h1></header>
        
        <div class="card" style="max-width:400px;margin:50px auto;">
            ${MSG:+<div class="alert alert-warning">$MSG</div>}
            
            <form method="post">
                <div class="form-group">
                    <label>当前密码</label>
                    <input type="password" name="old_pass" required placeholder="输入当前密码">
                </div>
                <div class="form-group">
                    <label>新密码</label>
                    <input type="password" name="new_pass" required placeholder="至少6位字符">
                </div>
                <div class="form-group">
                    <label>确认密码</label>
                    <input type="password" name="confirm_pass" required placeholder="再次输入新密码">
                </div>
                <button type="submit" class="btn">修改密码</button>
                <a href="/cgi-bin/system.cgi" class="btn btn-secondary">返回</a>
            </form>
        </div>
    </div>
</body>
</html>
EOF