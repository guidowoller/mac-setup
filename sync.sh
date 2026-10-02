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

# Kopiert nur, wenn Quelle und Ziel nicht dieselbe Datei sind
# (dotfiles/starship sind per Symlink ins Repo verlinkt -> nichts zu tun).
sync_file() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0
    [ "$src" -ef "$dst" ] && return 0
    cp "$src" "$dst"
}

# ----------------------------
# dotfiles
# ----------------------------

sync_file ~/.zshrc "$REPO/dotfiles/.zshrc"
sync_file ~/.zshrc.iterm "$REPO/dotfiles/.zshrc.iterm"
sync_file ~/.vimrc "$REPO/dotfiles/.vimrc"
sync_file ~/.nanorc "$REPO/dotfiles/.nanorc"
sync_file ~/.tmux.conf "$REPO/dotfiles/.tmux.conf"
sync_file ~/.gitconfig "$REPO/dotfiles/.gitconfig"

# ----------------------------
# ssh config: bewusst NICHT zurueckgesynct
# ----------------------------
# ~/.ssh/config wird aus Templates erzeugt und kann Uni-Daten enthalten.

# ----------------------------
# starship config
# ----------------------------

STARSHIP_SRC="$HOME/.config/starship.toml"
STARSHIP_DST="$REPO/config/starship.toml"

sync_file "$STARSHIP_SRC" "$STARSHIP_DST"

# ----------------------------
# vscode settings
# ----------------------------

VSCODE="$HOME/Library/Application Support/Code/User"

sync_file "$VSCODE/settings.json" "$REPO/vscode/settings.json"
sync_file "$VSCODE/keybindings.json" "$REPO/vscode/keybindings.json"

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

# Normalfall: ~/.config/nvim ist Symlink ins Repo -> nichts zu synchronisieren.
# Nur wenn es ein echtes Verzeichnis ist, wird es ins Repo gespiegelt (ohne zu loeschen).
if [ -d "$NVIM_SRC" ] && [ ! -L "$NVIM_SRC" ] && ! [ "$NVIM_SRC" -ef "$NVIM_DST" ]; then
    mkdir -p "$NVIM_DST"
    rsync -a --exclude 'nvim' "$NVIM_SRC"/ "$NVIM_DST"/
fi

# ----------------------------
# 1password agent
# ----------------------------

sync_file ~/.config/1password/ssh/agent.toml "$REPO/1password/agent.toml"

# ----------------------------
# wireguard: bewusst NICHT zurueckgesynct
# ----------------------------
# Die Templates im Repo sind massgeblich (nur Platzhalter). Installierte Configs
# enthalten Key, Adresse und Server-Daten und duerfen nie ins Repo zurueck.

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

