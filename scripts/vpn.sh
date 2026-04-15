#!/bin/bash

CMD="$1"

WG1="wg-fim5"
WG2="wg-faith"

is_running() {
    sudo wg show interfaces | grep -q "$1"
}

start_wg() {
    if ! is_running "$1"; then
        echo "Starting $1 ..."
        sudo wg-quick up "$1"
    else
        echo "$1 already running"
    fi
}

stop_wg() {
    echo "Stopping $1 ..."
    sudo wg-quick down "$1" 2>/dev/null || true
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

    	WG_OUTPUT=$(sudo wg show)

    	check_wg() {
    	    NAME="$1"
    	    MATCH="$2"

    	    if echo "$WG_OUTPUT" | grep -q "$MATCH"; then
    	        echo "✔ $NAME active"
    	    else
    	        echo "✖ $NAME inactive"
    	    fi
    	}

    	# typische eindeutige Netze aus deinen configs
    	check_wg "wg-fim5" "132.231.0.0/17"
    	check_wg "wg-faith" "10.7.0.0/16"

        ;;
esac
