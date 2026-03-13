#!/bin/bash

echo ""
echo "Running mac setup doctor..."
echo ""

# ----------------------------

# Homebrew

# ----------------------------

if command -v brew >/dev/null 2>&1; then
echo "✓ Homebrew installed"
else
echo "✗ Homebrew missing"
fi

# ----------------------------

# important tools

# ----------------------------

for cmd in tmux fzf eza starship wireguard-tools; do
if command -v $cmd >/dev/null 2>&1; then
echo "✓ $cmd installed"
else
echo "✗ $cmd missing"
fi
done

# ----------------------------

# SSH agent

# ----------------------------

if ssh-add -l >/dev/null 2>&1; then
echo "✓ SSH agent running"
else
echo "✗ SSH agent not running"
fi

# ----------------------------

# WireGuard configs

# ----------------------------

WG_DIR="/opt/homebrew/etc/wireguard"

if [ -d "$WG_DIR" ]; then
echo "✓ WireGuard directory exists"
else
echo "✗ WireGuard directory missing"
fi

# ----------------------------

# VS Code CLI

# ----------------------------

if command -v code >/dev/null 2>&1; then
echo "✓ VS Code CLI available"
else
echo "✗ VS Code CLI missing"
fi

# ----------------------------

# user scripts

# ----------------------------

if [ -d "$HOME/bin" ]; then
echo "✓ ~/bin exists"
else
echo "✗ ~/bin missing"
fi

echo ""
echo "Doctor check finished."
echo ""

