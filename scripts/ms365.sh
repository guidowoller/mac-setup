#!/bin/bash

set -e
# colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

PLIST="$HOME/Library/LaunchAgents/com.guido.ms365sync.plist"
SCRIPT="$HOME/bin/ms365sync.scpt"
LOG_OUT="$HOME/Library/Logs/ms365sync.out.log"
LOG_ERR="$HOME/Library/Logs/ms365sync.err.log"
INTERVAL_DEFAULT=3600

cmd="$1"

echo ""
echo "MS365 Sync Tool"
echo "----------------------------"

case "$cmd" in

  check)
    echo ""
    echo "Check"
    echo "-----------------"

    # --- letzter Logeintrag ---
    if [ ! -f "$LOG_OUT" ]; then
        echo "Last run:   never"
        echo "Status:     FAIL (no log file)"
        exit 1
    fi

    LAST_LINE=$(grep "ms365sync:" "$LOG_OUT" | tail -n 1)

    if [ -z "$LAST_LINE" ]; then
        echo "Last run:   never"
        echo "Status:     FAIL (no runs found)"
        exit 1
    fi

    LAST_TS=$(echo "$LAST_LINE" | awk '{print $1}')
    LAST_STATUS=$(echo "$LAST_LINE" | sed 's/^.*ms365sync: //')

    LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$LAST_TS" "+%s")
    NOW_EPOCH=$(date "+%s")

    # --- Intervall aus launchctl ---
    INTERVAL=$(launchctl print gui/$(id -u)/com.guido.ms365sync 2>/dev/null | grep "run interval" | awk '{print $4}')
    [ -z "$INTERVAL" ] && INTERVAL=$INTERVAL_DEFAULT

    NEXT_EPOCH=$((LAST_EPOCH + INTERVAL))
    REMAINING=$((NEXT_EPOCH - NOW_EPOCH))

    LAST_STR=$(date -r "$LAST_EPOCH" "+%Y-%m-%d %H:%M:%S")
    NOW_STR=$(date "+%Y-%m-%d %H:%M:%S")
    NEXT_STR=$(date -r "$NEXT_EPOCH" "+%Y-%m-%d %H:%M:%S")

    DELTA=$((NOW_EPOCH - LAST_EPOCH))
    OVERDUE=$((DELTA - INTERVAL))

    # --- LaunchAgent Status ---
    AGENT_INFO=$(launchctl print gui/$(id -u)/com.guido.ms365sync 2>/dev/null)

    if echo "$AGENT_INFO" | grep -q "state ="; then
        AGENT_LOADED="yes"
	STATE=$(echo "$AGENT_INFO" | grep "state =" | head -n1 | cut -d'=' -f2 | xargs)
    else
        AGENT_LOADED="no"
        STATE="unknown"
    fi

    # --- Status berechnen ---
    STATUS="OK"

    if echo "$LAST_STATUS" | grep -q "ERROR"; then
        STATUS="FAIL"
    elif [ "$DELTA" -gt "$INTERVAL" ]; then
        STATUS="FAIL"
    elif echo "$LAST_STATUS" | grep -q "WARN"; then
        STATUS="WARN"
    fi

    # --- Output ---
    echo "Last run:   $LAST_STR"
    echo "Now:        $NOW_STR"
    if [ "$REMAINING" -gt 0 ]; then
      REMAIN_MIN=$((REMAINING / 60))
      echo "Next run:   $NEXT_STR (in ${REMAIN_MIN} min)"
    else
      echo "Next run:   $NEXT_STR"
    fi
    echo ""
    echo "Last result: $LAST_STATUS"
    echo ""
    echo "Agent:      $AGENT_LOADED"
    echo "State:      $STATE"
    echo ""
    if [ "$STATUS" = "FAIL" ] && [ "$OVERDUE" -gt 0 ]; then
      OVERDUE_MIN=$((OVERDUE / 60))
      echo -e "Overall:     ${RED}FAIL${RESET} (overdue by ${OVERDUE_MIN} min)"
    elif [ "$STATUS" = "WARN" ]; then
      echo -e "Overall:    ${YELLOW}WARN${RESET} (slow execution)"
    else
      echo -e "Overall:    ${GREEN}OK${RESET}"
    fi
    echo ""
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
