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
mkdir -p $REPO/1password

# ----------------------------
# dotfiles
# ----------------------------

[ -f ~/.zshrc ] && cp ~/.zshrc $REPO/dotfiles/
[ -f ~/.zshrc.iterm ] && cp ~/.zshrc.iterm $REPO/dotfiles/
[ -f ~/.vimrc ] && cp ~/.vimrc $REPO/dotfiles/
[ -f ~/.nanorc ] && cp ~/.nanorc $REPO/dotfiles/
[ -f ~/.tmux.conf ] && cp ~/.tmux.conf $REPO/dotfiles/
[ -f ~/.gitconfig ] && cp ~/.gitconfig $REPO/dotfiles/

# ----------------------------
# ssh config
# ----------------------------

[ -f ~/.ssh/config ] && cp ~/.ssh/config $REPO/ssh/

# ----------------------------
# starship config
# ----------------------------

if [ -f ~/.config/starship.toml ]; then
    cp ~/.config/starship.toml $REPO/config/
    echo "✓ starship config synced"
else
    echo "⚠️ no starship config found"
fi

# ----------------------------
# vscode settings
# ----------------------------

VSCODE="$HOME/Library/Application Support/Code/User"

[ -f "$VSCODE/settings.json" ] && cp "$VSCODE/settings.json" $REPO/vscode/
[ -f "$VSCODE/keybindings.json" ] && cp "$VSCODE/keybindings.json" $REPO/vscode/

code --list-extensions > $REPO/vscode/extensions.txt 2>/dev/null || true

# ----------------------------
# scripts (optional safety sync)
# ----------------------------

BIN_DIR="$HOME/bin"
SCRIPT_DIR="$REPO/scripts"

for f in "$BIN_DIR"/*.sh; do
    [ -f "$f" ] || continue

    name=$(basename "$f")

    if [ ! -f "$SCRIPT_DIR/$name" ]; then
        echo "⚠️ Script missing in repo: $name"
    fi
done


# ----------------------------
# nvim config
# ----------------------------

NVIM_SRC="$HOME/.config/nvim"
NVIM_DST="$REPO/config/nvim"

if [ -d "$NVIM_SRC" ]; then
    rm -rf "$NVIM_DST"
    cp -R "$NVIM_SRC" "$NVIM_DST"
fi

# ----------------------------
# 1password agent
# ----------------------------

[ -f ~/.config/1password/ssh/agent.toml ] && cp ~/.config/1password/ssh/agent.toml $REPO/1password/

# ----------------------------
# wireguard templates
# ----------------------------

WG_SRC="/opt/homebrew/etc/wireguard"
WG_DST="$REPO/wireguard"

mkdir -p "$WG_DST"

for f in "$WG_SRC"/*.conf; do
[ -f "$f" ] || continue
fname=$(basename "$f")

sed 's/^PrivateKey.*/PrivateKey = <ENTER_PRIVATE_KEY_HERE>/' "$f" \
    > "$WG_DST/$fname"

done

# ----------------------------
# iTerm2 profiles (check)
# ----------------------------

ITERM_PROFILE="$REPO/config/iterm2-profiles.json"
ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

if [ ! -f "$ITERM_PROFILE" ]; then
    echo ""
    echo "⚠️  iTerm2 profiles missing!"
    echo "Export them manually:"
    echo "iTerm2 → Settings → Profiles → Other Actions → Export JSON Profiles"
    echo "Save to: $ITERM_PROFILE"
    echo ""
else
    if [ -f "$ITERM_PLIST" ] && [ "$ITERM_PROFILE" -ot "$ITERM_PLIST" ]; then
        echo ""
        echo "⚠️  iTerm2 profiles outdated!"
        echo "You changed iTerm settings but did not re-export profiles."
        echo "Please re-export to: $ITERM_PROFILE"
        echo ""
    else
        echo "✓ iTerm2 profiles up to date"
    fi
fi

echo "Sync complete."

