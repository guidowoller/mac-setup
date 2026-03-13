#!/bin/bash

echo "Starting UNI environment..."

WG1="wg-fim5"
WG2="wg-faith"

start_wg () {
if ! sudo wg show interfaces | grep -q "$1"; then
echo "Starting $1 ..."
sudo wg-quick up "$1"
else
echo "$1 already running"
fi
}

start_wg $WG1
sleep 1
start_wg $WG2

echo ""
echo "Active WireGuard interfaces:"
sudo wg show interfaces

echo ""
echo "Connecting to cervicales..."

ssh cervicales.fim.uni-passau.de -t "tmux attach -t uni || tmux new -s uni"

