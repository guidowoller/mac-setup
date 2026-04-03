#!/bin/bash

set -e

PLIST="$HOME/Library/LaunchAgents/com.guido.ms365sync.plist"
SCRIPT="$HOME/bin/ms365sync_strict_v3.scpt"
LOG_OUT="$HOME/Library/Logs/ms365sync.out.log"
LOG_ERR="$HOME/Library/Logs/ms365sync.err.log"
INTERVAL_DEFAULT=3600

cmd="$1"

echo ""
echo "MS365 Sync Tool"
echo "----------------------------"

case "$cmd" in

  check)
    echo "Checking MS365 Calendar Sync..."
    echo ""

    # LaunchAgent vorhanden?
    if [ -f "$PLIST" ]; then
        echo "✔ LaunchAgent exists"
    else
        echo "❌ LaunchAgent missing"
    fi

    # LaunchAgent geladen?
    if launchctl list | grep -q "com.guido.ms365sync"; then
        echo "✔ LaunchAgent loaded"
    else
        echo "❌ LaunchAgent not loaded"
    fi

    # Script vorhanden?
    if [ -f "$SCRIPT" ]; then
        echo "✔ Sync script exists"
    else
        echo "❌ Sync script missing"
    fi

    # letzter Lauf
    if [ -f "$LOG_OUT" ]; then
        LAST_RUN=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOG_OUT")
        echo "Last run: $LAST_RUN"
    else
        echo "No run yet"
    fi

    # Fehler anzeigen
    if [ -f "$LOG_ERR" ] && [ -s "$LOG_ERR" ]; then
        echo ""
        echo "⚠️ Errors found:"
        echo "----------------------------------------"
        tail -n 10 "$LOG_ERR"
        echo "----------------------------------------"
    else
        echo "✔ No errors in log"
    fi

    echo ""
    echo "Check complete."
    ;;

  run)
    echo "Running sync manually..."
    echo ""

    if [ ! -f "$SCRIPT" ]; then
        echo "❌ Script not found: $SCRIPT"
        exit 1
    fi

    echo "Executing..."
    echo ""

    /usr/bin/osascript "$SCRIPT"

    echo ""
    echo "✔ Sync finished"
    ;;

  restart)
    echo "Restarting LaunchAgent..."
    echo ""

    launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
    launchctl bootstrap gui/$(id -u) "$PLIST"

    echo "✔ Restarted"
    ;;

  log)
    echo "Showing last log output..."
    echo ""

    if [ -f "$LOG_OUT" ]; then
        tail -n 20 "$LOG_OUT"
    else
        echo "No log file found"
    fi
    ;;

      clear)
    echo "Clearing MS365 logs..."
    echo ""

    if [ -f "$LOG_OUT" ]; then
        > "$LOG_OUT"
        echo "✔ Cleared output log"
    else
        echo "No output log found"
    fi

    if [ -f "$LOG_ERR" ]; then
        > "$LOG_ERR"
        echo "✔ Cleared error log"
    else
        echo "No error log found"
    fi

    echo ""
    echo "Logs cleared."
    ;;

      status)
    echo "MS365 Sync Status"
    echo "----------------------------"

    STATUS_OK=true

    # LaunchAgent
    if launchctl list | grep -q "com.guido.ms365sync"; then
        echo "Agent:        ✔ running"
    else
        echo "Agent:        ❌ not running"
        STATUS_OK=false
    fi

    # Script
    if [ -f "$SCRIPT" ]; then
        echo "Script:       ✔ present"
    else
        echo "Script:       ❌ missing"
        STATUS_OK=false
    fi

    # letzter Lauf
    if [ -f "$LOG_OUT" ]; then
        LAST_RUN=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOG_OUT")
        echo "Last run:     $LAST_RUN"
    else
        echo "Last run:     unknown"
        STATUS_OK=false
    fi

    # Fehlerstatus
    if [ -f "$LOG_ERR" ] && [ -s "$LOG_ERR" ]; then
        echo "Errors:       ❌ present"
        STATUS_OK=false
    else
        echo "Errors:       ✔ none"
    fi

    echo ""

    if [ "$STATUS_OK" = true ]; then
        echo "Overall:      ✔ OK"
    else
        echo "Overall:      ❌ Issues detected"
    fi

    ;;

    stop)
    echo "Stopping MS365 LaunchAgent..."
    echo ""

    if launchctl list | grep -q "com.guido.ms365sync"; then
        launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
        echo "✔ Agent stopped"
    else
        echo "Agent not running"
    fi
    ;;

    start)
    INTERVAL="$2"

    if [ -z "$INTERVAL" ]; then
        INTERVAL=$INTERVAL_DEFAULT
    fi

    echo "Starting MS365 LaunchAgent..."
    echo "Interval: $INTERVAL seconds"
    echo ""

    if [ ! -f "$PLIST" ]; then
        echo "❌ LaunchAgent not found: $PLIST"
        exit 1
    fi

    TMP_PLIST=$(mktemp)

    # StartInterval ersetzen (robust, single-line)
    sed "s|<integer>[0-9]*</integer>|<integer>$INTERVAL</integer>|" "$PLIST" > "$TMP_PLIST"

    # alten stoppen
    launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true

    # neuen setzen
    mv "$TMP_PLIST" "$PLIST"

    # neu starten
    launchctl bootstrap gui/$(id -u) "$PLIST"

    echo "✔ Agent started"
    ;;

  *)
    echo "Usage:"
    echo "  ms365 status    → kompakter Status"
    echo "  ms365 check     → status prüfen"
    echo "  ms365 run       → sync manuell starten"
    echo "  ms365 restart   → LaunchAgent neu starten"
    echo "  ms365 log       → letzte Logs anzeigen"
    echo "  ms365 clear     → logs löschen"
    echo "  ms365 start [sec] → Agent starten (optional Intervall)"
    echo "  ms365 stop        → Agent stoppen"
    echo ""
    exit 1
    ;;

esac
