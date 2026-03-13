#!/bin/bash

echo "Starting work VPNs..."

sudo wg-quick up wg-fim5

sleep 2

sudo wg-quick up wg-faith

echo "Active interfaces:"
sudo wg show interfaces
