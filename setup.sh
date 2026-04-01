#!/bin/bash

set -e

REPO="$HOME/mac-setup"

echo "Running mac setup..."

# ----------------------------
# Homebrew packages
# ----------------------------

if command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew packages..."
    brew update || true
    brew bundle --file "$REPO/Brewfile"
else
    echo "Homebrew not installed. Please run bootstrap.sh first."
fi

# ensure brew in PATH
if [ -d "/opt/homebrew/bin" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ----------------------------
# remove quarantine for installed apps
# ----------------------------

echo "Removing quarantine flags from installed applications..."

for app in /Applications/*.app; do
    [ -d "$app" ] || continue
    echo "→ $app"
    xattr -dr com.apple.quarantine "$app" 2>/dev/null || true
done

# ----------------------------
# dotfiles
# ----------------------------

echo "Installing dotfiles..."

ln -sf "$REPO/dotfiles/.zshrc" "$HOME/.zshrc"
ln -sf "$REPO/dotfiles/.zshrc.iterm" "$HOME/.zshrc.iterm"
ln -sf "$REPO/dotfiles/.vimrc" "$HOME/.vimrc"
ln -sf "$REPO/dotfiles/.nanorc" "$HOME/.nanorc"
ln -sf "$REPO/dotfiles/.gitconfig" "$HOME/.gitconfig"
ln -sf "$REPO/dotfiles/.tmux.conf" "$HOME/.tmux.conf"

# ----------------------------
# scripts (symlinks, robust)
# ----------------------------

echo "Installing scripts (symlinks)..."

BIN_DIR="$HOME/bin"
SCRIPT_DIR="$REPO/scripts"

mkdir -p "$BIN_DIR"

# wichtig: verhindert Probleme bei leeren Matches
shopt -s nullglob

SCRIPT_FILES=("$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.scpt)

if [ ${#SCRIPT_FILES[@]} -eq 0 ]; then
    echo "No scripts found in $SCRIPT_DIR"
else
    for f in "${SCRIPT_FILES[@]}"; do
        if [ ! -f "$f" ]; then
            continue
        fi

        name=$(basename "$f")
        target="$BIN_DIR/$name"

        echo "→ linking $name"

        # existiert und ist KEIN symlink → löschen
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "  removing existing file"
            rm -f "$target"
        fi

        # symlink setzen (immer überschreiben)
        ln -sf "$f" "$target"

        # ausführbar machen (falls sinnvoll)
        chmod +x "$f" 2>/dev/null || true
    done
fi

# optional: zurücksetzen (sauberkeit)
shopt -u nullglob

# ----------------------------
# 1Password SSH agent setup
# ----------------------------

open -a "1Password"

echo ""
echo "--------------------------------------------------"
echo "Manual step required"
echo ""
echo "Please open 1Password now and enable:"
echo ""
echo "1Password → Settings → Developer → Use SSH Agent"
echo ""
echo "After enabling it, press ENTER to continue..."
echo "--------------------------------------------------"
echo ""

read -r

# ----------------------------
# 1Password SSH agent config
# ----------------------------

echo "Installing 1Password SSH agent configuration..."

OP_DIR="$HOME/.config/1password/ssh"
mkdir -p "$OP_DIR"

cp "$REPO/1password/agent.toml" "$OP_DIR/agent.toml" 2>/dev/null || true

# ----------------------------
# ms365 sync (LaunchAgent)
# ----------------------------

echo "Installing ms365 sync LaunchAgent..."

LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.guido.ms365sync.plist"
PLIST_SRC="$REPO/launchagents/$PLIST_NAME"
PLIST_DST="$LAUNCHAGENT_DIR/$PLIST_NAME"

mkdir -p "$LAUNCHAGENT_DIR"
mkdir -p "$HOME/Library/Logs"

chmod +x "$REPO/scripts/ms365sync_strict_v3.scpt"

TMP_PLIST=$(mktemp)
sed "s|\$HOME|$HOME|g" "$PLIST_SRC" > "$TMP_PLIST"

launchctl bootout gui/$(id -u) "$PLIST_DST" 2>/dev/null || true
ln -sf "$TMP_PLIST" "$PLIST_DST"
launchctl bootstrap gui/$(id -u) "$PLIST_DST" 2>/dev/null || true

echo "ms365 sync ready."

# ----------------------------
# starship config (symlink)
# ----------------------------

echo "Installing starship configuration..."

mkdir -p "$HOME/.config"

STARSHIP_SRC="$REPO/config/starship.toml"
STARSHIP_DST="$HOME/.config/starship.toml"

if [ -e "$STARSHIP_DST" ] && [ ! -L "$STARSHIP_DST" ]; then
    rm -f "$STARSHIP_DST"
fi

ln -sf "$STARSHIP_SRC" "$STARSHIP_DST"

# ----------------------------
# nvim config (symlink)
# ----------------------------

echo "Installing Neovim config..."

NVIM_SRC="$REPO/config/nvim"
NVIM_DST="$HOME/.config/nvim"

mkdir -p "$HOME/.config"

# alte config entfernen (falls kein symlink)
if [ -e "$NVIM_DST" ] && [ ! -L "$NVIM_DST" ]; then
    rm -rf "$NVIM_DST"
fi

# symlink setzen
ln -sf "$NVIM_SRC" "$NVIM_DST"

# sicherstellen dass keine alte init.vim Probleme macht
if [ -f "$NVIM_DST/init.vim" ]; then
    rm -f "$NVIM_DST/init.vim"
fi

# ----------------------------
# lazy.nvim bootstrap
# ----------------------------

LAZY_DIR="$HOME/.local/share/nvim/lazy/lazy.nvim"

if [ ! -d "$LAZY_DIR" ]; then
    echo "Installing lazy.nvim..."
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git "$LAZY_DIR" 2>/dev/null || true
fi

# ----------------------------
# plugins installieren (silent)
# ----------------------------

if command -v nvim >/dev/null 2>&1; then
    echo "Installing Neovim plugins..."

    # Plugins installieren
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

    # zweiter Run → stabilisiert Runtime
    nvim --headless "+qa" 2>/dev/null || true
fi

# ----------------------------
# iTerm2 profiles
# ----------------------------

echo "Configuring iTerm2..."

ITERM_PROFILE_DIR="$REPO/config"

if [ -f "$ITERM_PROFILE_DIR/iterm2-profiles.json" ]; then
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM_PROFILE_DIR"
fi

killall iTerm2 2>/dev/null || true


# ----------------------------
# ssh config
# ----------------------------

echo "Installing SSH config..."

mkdir -p "$HOME/.ssh"

if [ ! -f "$HOME/.ssh/config" ]; then
    cp "$REPO/ssh/config" "$HOME/.ssh/"
else
    echo "SSH config already exists – skipping."
fi

# ----------------------------
# wireguard environment
# ----------------------------

echo ""
echo "WireGuard configuration"
echo "Is this a UNI or PRIVATE Mac?"
echo ""
echo "u = university mac"
echo "p = private mac"
echo ""

read -rp "[u/p]: " WG_ENV

case "$WG_ENV" in
  u|U)
    WG_FIM_ITEM="WG-FIM5 Neu Guido Mac Uni"
    WG_FAITH_ITEM="WG-FAITH Neu Guido Mac Uni"
    ;;
  p|P)
    WG_FIM_ITEM="WG-FIM5 Neu Guido Mac Privat"
    WG_FAITH_ITEM="WG-FAITH Neu Guido Mac Privat"
    ;;
  *)
    echo "Invalid selection. Please run setup again."
    exit 1
    ;;
esac

# ----------------------------
# wireguard configs
# ----------------------------

echo "Installing WireGuard configs..."

WG_SRC="$REPO/wireguard"
WG_DST="/opt/homebrew/etc/wireguard"

sudo mkdir -p "$WG_DST"

# Werte aus 1Password holen
WG_FIM_KEY=$(op item get "$WG_FIM_ITEM" --fields private 2>/dev/null || true)
WG_FIM_IP=$(op item get "$WG_FIM_ITEM" --fields address 2>/dev/null || true)
WG_FAITH_KEY=$(op item get "$WG_FAITH_ITEM" --fields private 2>/dev/null || true)
WG_FAITH_IP=$(op item get "$WG_FAITH_ITEM" --fields address 2>/dev/null || true)

for f in "$WG_SRC"/*.conf; do
    [ -f "$f" ] || continue

    fname=$(basename "$f")

    case "$fname" in
        wg-fim5.conf)
            KEY="$WG_FIM_KEY"
            IP="$WG_FIM_IP"
            ;;
        wg-faith.conf)
            KEY="$WG_FAITH_KEY"
            IP="$WG_FAITH_IP"
            ;;
        *)
            KEY=""
            IP=""
            ;;
    esac

    if [ -n "$KEY" ] && [ -n "$IP" ]; then
        sed -e "s|<ENTER_PRIVATE_KEY_HERE>|$KEY|" \
            -e "s|<ENTER_IP_ADDRESS_HERE>|$IP|" \
            "$f" | sudo tee "$WG_DST/$fname" > /dev/null
    else
        echo "Skipping $fname (missing key or IP)"
        sudo cp "$f" "$WG_DST/$fname"
    fi

    sudo chmod 600 "$WG_DST/$fname"
done

echo ""
echo "Configuring sudo for WireGuard..."

USER_NAME=$(whoami)
SUDOERS_FILE="/etc/sudoers.d/wireguard"

# nur schreiben wenn noch nicht vorhanden
if ! sudo grep -q "wg-quick" "$SUDOERS_FILE" 2>/dev/null; then
    echo "$USER_NAME ALL=(ALL) NOPASSWD: /opt/homebrew/bin/wg-quick, /opt/homebrew/bin/wg" | \
    sudo tee "$SUDOERS_FILE" >/dev/null

    sudo chmod 440 "$SUDOERS_FILE"
fi

# ----------------------------
# Eclipse manual plugin step
# ----------------------------

echo ""
echo "--------------------------------------------------"
echo "Manual step required: Apache Directory Studio"
echo ""
echo "Help → Install New Software"
echo "https://directory.apache.org/studio/update/"
echo "Install: LDAP Browser"
echo ""
echo "--------------------------------------------------"
echo ""

ECLIPSE_BIN="/Applications/Eclipse Java.app/Contents/MacOS/eclipse"

if [ -x "$ECLIPSE_BIN" ]; then
    echo "Launching Eclipse..."
    "$ECLIPSE_BIN" &
    sleep 5
fi

echo ""
echo "Press ENTER to continue once finished..."
read -r

# ----------------------------
# initialize workspace
# ----------------------------

WORKSPACE="$HOME/eclipse-workspace"

if [ ! -d "$WORKSPACE/.metadata" ]; then
    echo "Initializing Eclipse workspace..."

    mkdir -p "$WORKSPACE"

    if [ -x "$ECLIPSE_BIN" ]; then
        "$ECLIPSE_BIN" -nosplash -data "$WORKSPACE" &
        ECLIPSE_PID=$!

        sleep 5

        kill $ECLIPSE_PID 2>/dev/null || true
        wait $ECLIPSE_PID 2>/dev/null || true
    fi
fi

# ----------------------------
# restore LDAP config
# ----------------------------

echo "Restoring Apache Directory Studio configuration..."

LDAP_DST="$WORKSPACE/.metadata/.plugins"
LDAP_SRC="$REPO/apache-directory-studio"

mkdir -p "$LDAP_DST"

if [ -d "$LDAP_SRC" ]; then
    cp -R "$LDAP_SRC"/org.apache.directory.studio.* "$LDAP_DST"/
else
    echo "⚠️ LDAP config not found in repo"
fi

# ----------------------------
# vscode config
# ----------------------------

echo "Installing VS Code configuration..."

VSCODE_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_DIR"

[ -f "$REPO/vscode/settings.json" ] && cp "$REPO/vscode/settings.json" "$VSCODE_DIR/"
[ -f "$REPO/vscode/keybindings.json" ] && cp "$REPO/vscode/keybindings.json" "$VSCODE_DIR/"

CODE_BIN=""

if [ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
    CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
elif command -v code >/dev/null 2>&1; then
    CODE_BIN="code"
fi

if [ -n "$CODE_BIN" ]; then
	[ -f "$REPO/vscode/extensions.txt" ] && xargs -L 1 "$CODE_BIN" --install-extension < "$REPO/vscode/extensions.txt"
else
    echo "VS Code CLI not available – skipping extension installation."
fi

# ----------------------------
# Git remote
# ----------------------------

echo "Checking GitHub SSH access..."

if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    CURRENT_REMOTE=$(git remote get-url origin)

    if [[ "$CURRENT_REMOTE" == https://github.com/* ]]; then
        git remote set-url origin git@github.com:guidowoller/mac-setup.git
    fi
else
    echo "GitHub SSH not ready yet – keeping HTTPS remote."
fi

# ----------------------------
# macOS preferences
# ----------------------------

if [ -f "$REPO/macos/restore.sh" ]; then
    echo "Restoring macOS preferences..."

    if ! bash "$REPO/macos/restore.sh"; then
        echo "⚠️ macOS preferences restore had issues"
    fi
else
    echo "No macOS restore script found – skipping."
fi

# ----------------------------
# wallpaper
# ----------------------------

echo "Setting wallpaper..."

WALLPAPER="$REPO/assets/wallpaper.jpg"

if [ -f "$WALLPAPER" ]; then
    sleep 2

    osascript <<EOF
tell application "System Events"
    repeat with d in desktops
        set picture of d to "$WALLPAPER"
    end repeat
end tell
EOF
else
    echo "Wallpaper not found: $WALLPAPER"
fi

# ----------------------------
# Finished
# ----------------------------

echo ""
echo "Setup complete. Import README to Apple Notes..."
echo ""

sleep 2
open -a Notes "$REPO/README.md" 2>/dev/null || true
