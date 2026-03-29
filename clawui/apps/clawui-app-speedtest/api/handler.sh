#!/bin/sh
# Speedtest API Handler
ACTION="$1"; shift
SPEEDTEST_LOG="/var/log/speedtest.json"
case "$ACTION" in
    test)
        if command -v speedtest-cli > /dev/null 2>&1; then
            RESULT=$(speedtest-cli --simple 2>/dev/null)
            DOWNLOAD=$(echo "$RESULT" | grep "Download" | awk '{print $2}')
            UPLOAD=$(echo "$RESULT" | grep "Upload" | awk '{print $2}')
            # Save to history
            echo "{\"date\":\"$(date '+%Y-%m-%d %H:%M')\",\"download\":$DOWNLOAD,\"upload\":$UPLOAD}" >> "$SPEEDTEST_LOG"
            echo "{\"download\":$DOWNLOAD,\"upload\":$UPLOAD}"
        else
            echo '{"download": 0, "upload": 0, "error": "speedtest-cli not installed"}'
        fi
        ;;
    history)
        if [ -f "$SPEEDTEST_LOG" ]; then
            tail -10 "$SPEEDTEST_LOG" | jq -s '.' 2>/dev/null || echo '[]'
        else
            echo '[]'
        fi
        ;;
    *) echo '{"error": "Unknown"}' ;;
esac
