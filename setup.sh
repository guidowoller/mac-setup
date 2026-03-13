#!/bin/bash

set -e

REPO="$HOME/mac-setup"

echo "Running mac setup..."

# ----------------------------

# Homebrew packages

# ----------------------------

if command -v brew >/dev/null 2>&1; then
echo "Installing Homebrew packages..."
brew update
brew bundle --file "$REPO/Brewfile"
else
echo "Homebrew not installed. Please run bootstrap.sh first."
fi

# ----------------------------

# dotfiles

# ----------------------------

echo "Installing dotfiles..."

ln -sf "$REPO/dotfiles/.zshrc" ~/.zshrc
ln -sf "$REPO/dotfiles/.vimrc" ~/.vimrc
ln -sf "$REPO/dotfiles/.gitconfig" ~/.gitconfig
ln -sf "$REPO/dotfiles/.tmux.conf" ~/.tmux.conf

# ----------------------------

# scripts

# ----------------------------

echo "Installing scripts..."

mkdir -p ~/bin

for f in "$REPO/scripts/"*.sh; do
[ -f "$f" ] || continue
cp "$f" ~/bin/
chmod +x ~/bin/$(basename "$f")
done

# ----------------------------

# ssh config

# ----------------------------

echo "Installing SSH config..."

mkdir -p ~/.ssh

if [ ! -f ~/.ssh/config ]; then
cp "$REPO/ssh/config" ~/.ssh/
else
echo "SSH config already exists – skipping."
fi

# ----------------------------

# wireguard configs

# ----------------------------

echo "Installing WireGuard configs..."

sudo mkdir -p /opt/homebrew/etc/wireguard

for f in "$REPO/wireguard/"*.conf; do
[ -f "$f" ] || continue
sudo cp -n "$f" /opt/homebrew/etc/wireguard/
done

# ----------------------------

# WireGuard private key check

# ----------------------------

WG_DIR="/opt/homebrew/etc/wireguard"

if [ -d "$WG_DIR" ]; then
if grep -q "<ENTER_PRIVATE_KEY_HERE>" "$WG_DIR"/*.conf 2>/dev/null; then
echo ""
echo "⚠️  WireGuard configuration requires your private key."
echo ""
echo "Please edit the following files and insert the key from 1Password:"
echo ""
ls "$WG_DIR"/*.conf
echo ""
echo "Example:"
echo "vim /opt/homebrew/etc/wireguard/wg-faith.conf"
echo ""
fi
fi

# ----------------------------

# vscode config

# ----------------------------

echo "Installing VS Code configuration..."

VSCODE_DIR="$HOME/Library/Application Support/Code/User"

mkdir -p "$VSCODE_DIR"

[ -f "$REPO/vscode/settings.json" ] && cp "$REPO/vscode/settings.json" "$VSCODE_DIR/"
[ -f "$REPO/vscode/keybindings.json" ] && cp "$REPO/vscode/keybindings.json" "$VSCODE_DIR/"

if command -v code >/dev/null 2>&1; then
if [ -f "$REPO/vscode/extensions.txt" ]; then
cat "$REPO/vscode/extensions.txt" | xargs -L 1 code --install-extension
fi
else
echo "VS Code CLI not available – skipping extension installation."
fi

# ----------------------------

# macOS preferences

# ----------------------------

echo "Restoring macOS preferences..."

if [ -f "$REPO/macos/restore.sh" ]; then
bash "$REPO/macos/restore.sh" || true
fi

echo ""
echo "Setup complete."
echo ""

