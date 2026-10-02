#!/bin/bash
#
# vpn.sh - startet/stoppt die WireGuard-Tunnel (wg-fim5, wg-faith)
#
#   vpn start | stop | status
#
# Auf macOS heissen die Interfaces utunN, nicht wie die Config. Beim Start wird
# deshalb gemerkt, welches utun zu welchem Tunnel gehoert (~/.cache/vpn/<name>).
# So braucht der Status-Check keine Netzbereiche oder Adressen im Code.

CMD="$1"

WG1="wg-fim5"
WG2="wg-faith"

STATE_DIR="$HOME/.cache/vpn"
mkdir -p "$STATE_DIR"

iface_of() {
    cat "$STATE_DIR/$1" 2>/dev/null
}

is_running() {
    local iface
    iface="$(iface_of "$1")"
    [ -n "$iface" ] && sudo wg show interfaces | tr ' ' '\n' | grep -qx "$iface"
}

start_wg() {
    if is_running "$1"; then
        echo "$1 already running"
        return
    fi

    echo "Starting $1 ..."
    local out rc iface
    out="$(sudo wg-quick up "$1" 2>&1)"
    rc=$?
    echo "$out"

    iface="$(echo "$out" | sed -n "s/.*Interface for $1 is \(utun[0-9]*\).*/\1/p" | head -n 1)"
    if [ -n "$iface" ]; then
        echo "$iface" > "$STATE_DIR/$1"
    fi
    return $rc
}

stop_wg() {
    echo "Stopping $1 ..."
    sudo wg-quick down "$1" 2>/dev/null || true
    rm -f "$STATE_DIR/$1"
}

case "$CMD" in
    start)
        echo "Starting VPN..."
        start_wg "$WG1"
        sleep 1
        start_wg "$WG2"
        echo "VPN ready"
        ;;
    stop)
        echo "Stopping VPN..."
        stop_wg "$WG2"
        stop_wg "$WG1"
        echo "VPN stopped"
        ;;
    status)
        echo "VPN status:"
        echo ""

        for name in "$WG1" "$WG2"; do
            if is_running "$name"; then
                echo "✔ $name active ($(iface_of "$name"))"
            else
                echo "✖ $name inactive"
            fi
        done
        ;;
    *)
        echo "Usage: vpn start | stop | status"
        exit 1
        ;;
esac
