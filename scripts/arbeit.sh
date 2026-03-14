#!/bin/bash

echo ""
echo "==============================="
echo "      WORK ENVIRONMENT"
echo "==============================="
echo ""

ANSIBLE_HOST="cervicales.fim.uni-passau.de"

WG_HOME1="wg-fim5"
WG_HOME2="wg-faith"
WG_UNI="wg-faith"

# ----------------------------
# detect wifi interface
# ----------------------------

WIFI_IF=$(networksetup -listallhardwareports | 
awk '/Wi-Fi|AirPort/{getline; print $2}')

SSID=$(networksetup -getairportnetwork $WIFI_IF 2>/dev/null | awk -F': ' '{print $2}')

# ----------------------------
# detect primary IP
# ----------------------------

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)

echo "Network information:"
echo "IP:   $IP"
echo "SSID: $SSID"
echo ""

# ----------------------------
# helper: start wireguard
# ----------------------------

start_wg () {
    if ! sudo wg show interfaces | grep -q "$1"; then
        echo "Starting $1 ..."
        sudo wg-quick up "$1"
    else
        echo "$1 already running"
    fi
}

# ----------------------------
# environment detection
# ----------------------------

if [[ "$IP" == 132.231.* ]]; then

    ENV="University"

    echo "University network detected"

    echo "Disabling WiFi..."
    networksetup -setairportpower $WIFI_IF off 2>/dev/null || true

    start_wg $WG_UNI

elif [[ "$SSID" == "SID Kahale" || "$IP" == 192.168.4.* ]]; then

    ENV="Home"

    echo "Home network detected"

    start_wg $WG_HOME1
    sleep 1
    start_wg $WG_HOME2

else

    ENV="Unknown"

    echo "Unknown network → starting full VPN stack"

    start_wg $WG_HOME1
    sleep 1
    start_wg $WG_HOME2

fi

echo ""
echo "WireGuard interfaces:"
sudo wg show interfaces
echo ""

# ----------------------------
# wait for VPN connectivity
# ----------------------------

echo "Checking connectivity to ansible host..."

until ping -c1 $ANSIBLE_HOST >/dev/null 2>&1; do
    echo "Waiting for VPN routing..."
    sleep 2
done

echo "VPN connectivity established."
echo ""

# ----------------------------
# focus mode
# ----------------------------

echo "Enabling focus mode..."

shortcuts run "FokusArbeit" 2>/dev/null || true

# ----------------------------
# helper: start app if needed
# ----------------------------

start_app () {

APP="$1"
MINIMIZE="$2"

if ! pgrep -x "$APP" >/dev/null; then
    echo "Launching $APP"
    open -a "$APP"
    sleep 2
else
    echo "$APP already running"
fi

if [ "$MINIMIZE" = "min" ]; then
osascript <<EOF
tell application "$APP" to activate
delay 0.5
tell application "System Events"
    keystroke "m" using command down
end tell
EOF
fi

}

# ----------------------------
# start work apps
# ----------------------------

start_app "Mattermost" 
start_app "KeePassXC" 
start_app "Firefox"

echo ""
echo "Environment: $ENV"
echo "Work environment ready."
echo ""
echo "Connecting to ansible host..."

exec ~/bin/a.sh
