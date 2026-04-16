#!/bin/bash

MODE="$1"

WALLPAPER_DIR="$HOME/Documents/wallpaper"
STATE_FILE="$HOME/.mac-mode"

# ----------------------------
# helpers
# ----------------------------

start_app() {

APP="$1"
MODE="$2"

if ! pgrep -x "$APP" >/dev/null; then
    echo "Starting $APP"
    open -a "$APP"
    sleep 1
else
    echo "$APP already running"
fi

if [ "$MODE" = "min" ]; then
osascript <<EOF
tell application "$APP" to activate
delay 0.5
tell application "System Events"
    keystroke "m" using command down
end tell
EOF
fi

}

stop_app() {

APP="$1"

# läuft die App? → über AppleScript prüfen (zuverlässig!)
if osascript -e "tell application \"System Events\" to (name of processes) contains \"$APP\"" | grep -q true; then

    echo "Stopping $APP (graceful)"

    # sauber beenden
    osascript <<EOF
tell application "$APP" to quit
EOF

    sleep 2

    # fallback: kill nach Prozessnamen (lowercase)
    PROC=$(echo "$APP" | tr '[:upper:]' '[:lower:]')

    if pgrep -f "$PROC" >/dev/null; then
        echo "Force killing $APP"
        pkill -9 -f "$PROC"
    fi

fi

}

set_wallpaper() {
    wallpaper set "$1"
}

set_focus() {
    shortcuts run "$1" 2>/dev/null || true
}

# ----------------------------
# MODES
# ----------------------------

case "$MODE" in

# ----------------------------
arbeit)
    echo "Mode: Arbeit"

    set_focus "Arbeit"
    set_wallpaper "$WALLPAPER_DIR/wallpaper-arbeit.jpg"

    # stop leisure apps
    stop_app "Microsoft Edge"
    stop_app "WhatsApp"

    # start work apps
    start_app "Mattermost" min
    start_app "Mail" min
    start_app "Windows App" min
    start_app "LRZ Sync+Share"
    start_app "Firefox"

    # VPN
    ~/mac-setup/scripts/vpn.sh start
    echo "arbeit" > "$STATE_FILE"
    ;;

# ----------------------------
freizeit)
    echo "Mode: Freizeit"

    set_focus "Freizeit"
    set_wallpaper "$WALLPAPER_DIR/wallpaper-freizeit.jpg"

    # stop work apps
    stop_app "Firefox"
    stop_app "Mattermost"
    stop_app "Windows App"
    stop_app "LRZ Sync+Share"

    # start leisure apps
    start_app "WhatsApp" min
    start_app "Mail" min
    start_app "Microsoft Edge"

    # VPN
    ~/mac-setup/scripts/vpn.sh stop
    echo "freizeit" > "$STATE_FILE"
    ;;

# ----------------------------
alles)
    echo "Mode: Alles erlaubt"

    set_focus "Alles erlaubt"
    set_wallpaper "$WALLPAPER_DIR/wallpaper-alles-erlaubt.jpg"

    # start all apps
    start_app "Mattermost" min
    start_app "Mail" min
    start_app "Windows App" min
    start_app "WhatsApp" min 
    start_app "Firefox" min
    start_app "LRZ Sync+Share"
    start_app "Microsoft Edge" min

    # VPN
    ~/mac-setup/scripts/vpn.sh start
    echo "alles" > "$STATE_FILE"
    ;;

# ----------------------------
ich)
    echo "Mode: Zeit für mich"

    set_focus "Zeit für mich"
    set_wallpaper "$WALLPAPER_DIR/wallpaper-zeit-fuer-mich.jpg"

    # kill everything relevant
    stop_app "Firefox"
    stop_app "Mattermost"
    stop_app "Mail"
    stop_app "Windows App"
    stop_app "Microsoft Edge"
    stop_app "WhatsApp"
    stop_app "LRZ Sync+Share"
    stop_app "iTerm2"
    stop_app "Terminal"

    # VPN
    ~/mac-setup/scripts/vpn.sh stop
    echo "ich" > "$STATE_FILE"
    ;;

# ----------------------------

status)
    echo "Mode status:"
    echo ""

    # Mode
    if [ -f "$STATE_FILE" ]; then
        CURRENT_MODE=$(cat "$STATE_FILE")
        echo "Mode: $CURRENT_MODE"
    else
        echo "Mode: unknown"
    fi

    echo ""

    # VPN Status
    VPN_INTERFACES=$(sudo wg show interfaces)

    if [ -n "$VPN_INTERFACES" ]; then
        echo "VPN: active ($VPN_INTERFACES)"
    else
        echo "VPN: inactive"
    fi

    ;;

*)
    echo "Usage: mode {arbeit|freizeit|alles|ich|status}"
    exit 1
    ;;

esac
