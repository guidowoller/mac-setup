#!/bin/bash

set -e

echo "Running mac setup..."

# ----------------------------

# Homebrew packages

# ----------------------------

brew update
brew bundle --file ~/mac-setup/Brewfile

# ----------------------------

# dotfiles

# ----------------------------

echo "Installing dotfiles..."

ln -sf ~/mac-setup/dotfiles/.zshrc ~/.zshrc
ln -sf ~/mac-setup/dotfiles/.vimrc ~/.vimrc
ln -sf ~/mac-setup/dotfiles/.gitconfig ~/.gitconfig
ln -sf ~/mac-setup/dotfiles/.tmux.conf ~/.tmux.conf

# ----------------------------

# scripts

# ----------------------------

echo "Installing scripts..."

mkdir -p ~/bin
cp ~/mac-setup/scripts/*.sh ~/bin/ 2>/dev/null || true
chmod +x ~/bin/*.sh

# ----------------------------

# ssh config

# ----------------------------

mkdir -p ~/.ssh
cp ~/mac-setup/ssh/config ~/.ssh/ 2>/dev/null || true

# ----------------------------

# wireguard

# ----------------------------

echo "Installing wireguard configs..."

sudo mkdir -p /opt/homebrew/etc/wireguard
sudo cp ~/mac-setup/wireguard/*.conf /opt/homebrew/etc/wireguard/

# ----------------------------

# vscode config

# ----------------------------

mkdir -p "$HOME/Library/Application Support/Code/User"

cp ~/mac-setup/vscode/settings.json 
"$HOME/Library/Application Support/Code/User/" 2>/dev/null || true

cp ~/mac-setup/vscode/keybindings.json 
"$HOME/Library/Application Support/Code/User/" 2>/dev/null || true

cat ~/mac-setup/vscode/extensions.txt | 
xargs -L 1 code --install-extension 2>/dev/null || true

# ----------------------------

# macOS preferences

# ----------------------------

bash ~/mac-setup/macos/restore.sh 2>/dev/null || true

echo "Setup complete."

