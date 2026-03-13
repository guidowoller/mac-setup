#!/bin/bash

set -e

REPO="$HOME/mac-setup"

echo "Syncing configuration..."

# ----------------------------

# ensure directories exist

# ----------------------------

mkdir -p $REPO/dotfiles
mkdir -p $REPO/ssh
mkdir -p $REPO/scripts
mkdir -p $REPO/config
mkdir -p $REPO/vscode

# ----------------------------

# dotfiles

# ----------------------------

[ -f ~/.zshrc ] && cp ~/.zshrc $REPO/dotfiles/
[ -f ~/.vimrc ] && cp ~/.vimrc $REPO/dotfiles/
[ -f ~/.tmux.conf ] && cp ~/.tmux.conf $REPO/dotfiles/
[ -f ~/.gitconfig ] && cp ~/.gitconfig $REPO/dotfiles/

# ----------------------------

# ssh config

# ----------------------------

[ -f ~/.ssh/config ] && cp ~/.ssh/config $REPO/ssh/

# ----------------------------

# starship config

# ----------------------------

[ -f ~/.config/starship.toml ] && cp ~/.config/starship.toml $REPO/config/

# ----------------------------

# vscode settings

# ----------------------------

VSCODE="$HOME/Library/Application Support/Code/User"

[ -f "$VSCODE/settings.json" ] && cp "$VSCODE/settings.json" $REPO/vscode/
[ -f "$VSCODE/keybindings.json" ] && cp "$VSCODE/keybindings.json" $REPO/vscode/

code --list-extensions > $REPO/vscode/extensions.txt 2>/dev/null || true

echo "Sync complete."

