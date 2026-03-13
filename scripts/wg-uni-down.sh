#!/bin/bash

echo "Stopping UNI VPNs..."

sudo wg-quick down wg-faith 2>/dev/null || true
sudo wg-quick down wg-fim5 2>/dev/null || true

echo "VPNs stopped."

