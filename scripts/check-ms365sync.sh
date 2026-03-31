#!/bin/bash

set -e

LABEL="com.guido.ms365sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_OUT="$HOME/Library/Logs/ms365sync.out.log"
LOG_ERR="$HOME/Library/Logs/ms365sync.err.log"

echo "Checking MS365 Calendar Sync..."
echo ""

# ----------------------------
# 1. LaunchAgent vorhanden?
# ----------------------------

if [ -f "$PLIST" ]; then
    echo "✔ LaunchAgent exists"
else
    echo "❌ LaunchAgent missing: $PLIST"
    exit 1
fi

# ----------------------------
# 2. LaunchAgent geladen?
# ----------------------------

if launchctl list | grep -q "$LABEL"; then
    echo "✔ LaunchAgent loaded"
else
    echo "❌ LaunchAgent NOT loaded"
    exit 1
fi

# ----------------------------
# 3. Letzte Ausführung prüfen
# ----------------------------

LAST_RUN=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOG_OUT" 2>/dev/null || echo "never")

echo "Last run: $LAST_RUN"

# ----------------------------
# 4. Fehler prüfen
# ----------------------------

if [ -f "$LOG_ERR" ] && [ -s "$LOG_ERR" ]; then
    echo ""
    echo "⚠️ Errors found in log:"
    echo "----------------------------------------"
    tail -n 10 "$LOG_ERR"
    echo "----------------------------------------"
else
    echo "✔ No errors in log"
fi

# ----------------------------
# 5. Output prüfen (optional)
# ----------------------------

if [ -f "$LOG_OUT" ]; then
    echo ""
    echo "Last output:"
    echo "----------------------------------------"
    tail -n 5 "$LOG_OUT"
    echo "----------------------------------------"
else
    echo "⚠️ No output log found"
fi

echo ""
echo "Check complete."
