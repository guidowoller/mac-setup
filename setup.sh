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
# remove quarantine for installed apps
# ----------------------------

echo "Removing quarantine flags from installed applications..."

for app in /Applications/*.app; do
    [ -d "$app" ] || continue
    echo "→ $app"
    xattr -dr com.apple.quarantine "$app" 2>/dev/null || true
done

# ----------------------------
# initialize Eclipse (important for plugin system)
# ----------------------------

echo "Initializing Eclipse..."

ECLIPSE_BIN="/Applications/Eclipse Java.app/Contents/MacOS/eclipse"
ECLIPSE_DIR="/Applications/Eclipse Java.app/Contents/Eclipse"
WORKSPACE="$HOME/eclipse-workspace"

mkdir -p "$WORKSPACE"

if [ -x "$ECLIPSE_BIN" ]; then
    "$ECLIPSE_BIN" -nosplash -data "$WORKSPACE" &
    ECLIPSE_PID=$!

    sleep 8

    kill $ECLIPSE_PID 2>/dev/null || true
    wait $ECLIPSE_PID 2>/dev/null || true
else
    echo "Eclipse not found – skipping initialization."
fi

# ----------------------------
# install Apache Directory Studio plugin
# ----------------------------

echo "Installing Apache Directory Studio plugin..."

if [ -x "$ECLIPSE_BIN" ]; then
    "$ECLIPSE_BIN" \
        -nosplash \
        -application org.eclipse.equinox.p2.director \
        -repository https://directory.apache.org/studio/update/ \
        -installIU org.apache.directory.studio.feature.feature.group \
        -destination "$ECLIPSE_DIR" \
        -profile SDKProfile \
        -bundlepool "$ECLIPSE_DIR" \
        -profileProperties org.eclipse.update.install.features=true \
        -roaming || true
else
    echo "Eclipse not found – skipping plugin installation."
fi

# ----------------------------
# dotfiles
# ----------------------------

echo "Installing dotfiles..."

ln -sf "$REPO/dotfiles/.zshrc" ~/.zshrc
ln -sf "$REPO/dotfiles/.vimrc" ~/.vimrc
ln -sf "$REPO/dotfiles/.nanorc" ~/.nanorc
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
# starship config
# ----------------------------

echo "Installing starship configuration..."

mkdir -p ~/.config
cp "$REPO/config/starship.toml" ~/.config/starship.toml 2>/dev/null || true

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
    WG_FIM_ITEM="WG FIM-5 Neu Guido Mac Uni"
    WG_FAITH_ITEM="WG-FAITH Neu Guido Mac Uni"
    ;;
  p|P)
    WG_FIM_ITEM="WG FIM-5 Neu Guido-MacPrivat"
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

WG_SRC="$HOME/mac-setup/wireguard"
WG_DST="/opt/homebrew/etc/wireguard"

sudo mkdir -p "$WG_DST"

WG_FIM_KEY=$(op item get "$WG_FIM_ITEM" --fields private)
WG_FAITH_KEY=$(op item get "$WG_FAITH_ITEM" --fields private)

for f in "$WG_SRC"/*.conf; do
    [ -f "$f" ] || continue

    fname=$(basename "$f")

    case "$fname" in
        wg-fim5.conf) KEY="$WG_FIM_KEY" ;;
        wg-faith.conf) KEY="$WG_FAITH_KEY" ;;
        *) KEY="" ;;
    esac

    if [ -n "$KEY" ]; then
        sed "s|<ENTER_PRIVATE_KEY_HERE>|$KEY|" "$f" | sudo tee "$WG_DST/$fname" > /dev/null
    else
        sudo cp "$f" "$WG_DST/$fname"
    fi

    sudo chmod 600 "$WG_DST/$fname"
done

# ----------------------------
# restore LDAP config
# ----------------------------

echo "Restoring Apache Directory Studio configuration..."

LDAP_DST="$WORKSPACE/.metadata/.plugins"
LDAP_SRC="$REPO/apache-directory-studio"

mkdir -p "$LDAP_DST"
cp -R "$LDAP_SRC"/org.apache.directory.studio.* "$LDAP_DST"/ 2>/dev/null || true

# ----------------------------
# vscode config
# ----------------------------

echo "Installing VS Code configuration..."

VSCODE_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_DIR"

[ -f "$REPO/vscode/settings.json" ] && cp "$REPO/vscode/settings.json" "$VSCODE_DIR/"
[ -f "$REPO/vscode/keybindings.json" ] && cp "$REPO/vscode/keybindings.json" "$VSCODE_DIR/"

if command -v code >/dev/null 2>&1; then
    [ -f "$REPO/vscode/extensions.txt" ] && cat "$REPO/vscode/extensions.txt" | xargs -L 1 code --install-extension
else
    echo "VS Code CLI not available – skipping extension installation."
fi

# ----------------------------
# Switch Git remote to SSH
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

echo "Restoring macOS preferences..."

[ -f "$REPO/macos/restore.sh" ] && bash "$REPO/macos/restore.sh" || true

# ----------------------------
# wallpaper
# ----------------------------

echo "Setting wallpaper..."

WALLPAPER="$HOME/Library/Mobile Documents/com~apple~CloudDocs/bootstrap/wallpaper.jpg"

if [ -f "$WALLPAPER" ]; then
osascript <<EOF
tell application "System Events"
    tell every desktop
        set picture to "$WALLPAPER"
    end tell
end tell
EOF
else
    echo "Wallpaper not found: $WALLPAPER"
fi

echo ""
echo "Setup complete."
echo ""
