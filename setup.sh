#!/bin/bash

set -e

REPO="$HOME/mac-setup"

echo "Running mac setup..."

# ----------------------------
# Rolle dieses Macs (uni / privat)
# ----------------------------
# Wird einmal abgefragt und in ~/.mac-role gespeichert. Davon haengt ab:
# WireGuard-Items in 1Password und welche LaunchAgents installiert werden.

ROLE_FILE="$HOME/.mac-role"
MAC_ROLE=""

if [ -f "$ROLE_FILE" ]; then
    MAC_ROLE=$(tr -d '[:space:]' < "$ROLE_FILE")
fi

case "$MAC_ROLE" in
    uni|privat) ;;
    *)
        echo ""
        echo "Is this a UNI or PRIVATE Mac?"
        echo ""
        echo "u = university mac"
        echo "p = private mac"
        echo ""
        read -rp "[u/p]: " ROLE_ANSWER
        case "$ROLE_ANSWER" in
            u|U) MAC_ROLE="uni" ;;
            p|P) MAC_ROLE="privat" ;;
            *)
                echo "Invalid selection. Please run setup again."
                exit 1
                ;;
        esac
        echo "$MAC_ROLE" > "$ROLE_FILE"
        ;;
esac

echo "Mac role: $MAC_ROLE (stored in $ROLE_FILE)"

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

SCRIPT_FILES=("$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.py)

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
echo "1Password → Settings → Developer → Integrate with 1Password CLI"
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
# LaunchAgents (launchagents/*.plist)
# ----------------------------
# Jede Plist im Repo wird installiert, ausser sie ist fuer diese Rolle nicht
# vorgesehen. ms365sync (Kalender-Sync) laeuft bewusst nur auf dem privaten Mac,
# damit nicht mehrere Macs gleichzeitig in denselben iCloud-Kalender schreiben.

agent_wanted() {
    case "$1" in
        com.guido.ms365sync) [ "$MAC_ROLE" = "privat" ] ;;
        *) return 0 ;;
    esac
}

LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCHAGENT_DIR"
mkdir -p "$HOME/Library/Logs"

shopt -s nullglob
for PLIST_SRC in "$REPO"/launchagents/*.plist; do
    PLIST_NAME=$(basename "$PLIST_SRC")
    LABEL="${PLIST_NAME%.plist}"
    PLIST_DST="$LAUNCHAGENT_DIR/$PLIST_NAME"

    launchctl bootout gui/$(id -u) "$PLIST_DST" 2>/dev/null || true

    if agent_wanted "$LABEL"; then
        sed "s|\$HOME|$HOME|g" "$PLIST_SRC" > "$PLIST_DST"
        if launchctl bootstrap gui/$(id -u) "$PLIST_DST" 2>/dev/null; then
            echo "→ $LABEL installed and loaded"
        else
            echo "→ $LABEL installed (could not load, check: launchctl print gui/$(id -u)/$LABEL)"
        fi
    else
        rm -f "$PLIST_DST"
        echo "→ $LABEL skipped (not intended for role: $MAC_ROLE)"
    fi
done
shopt -u nullglob

echo "LaunchAgents ready."

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
ln -sfn "$NVIM_SRC" "$NVIM_DST"

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

# Hinweis: iTerm2-Einstellungen kommen aus macos/restore.sh (macos/preferences/iterm2.plist).
# Frueher wurde hier PrefsCustomFolder auf $REPO/config gesetzt und iTerm2 beendet.
# Das fuehrte zur Meldung "Missing or malformed file at .../config" (dort liegt keine
# com.googlecode.iterm2.plist) und beendete das Terminal, aus dem setup.sh lief.
# Eine eventuell vorhandene alte Einstellung wird hier entfernt.
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool false 2>/dev/null || true
defaults delete com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true


# ----------------------------
# Uni-Daten aus 1Password (Item "Mac-Setup Uni")
# ----------------------------
# WireGuard-Peers, LDAP-Host und SSH-Alias stehen nicht im oeffentlichen Repo,
# sondern als Vorlagen in templates/ ({{ op://... }}) und werden hier mit
# `op inject` gefuellt. Fehler werden gesammelt und am Ende angezeigt.

SETUP_WARNINGS=()
warn_setup() {
    echo "⚠️  $1"
    SETUP_WARNINGS+=("$1")
}

# Feldwert aus einem 1Password-Item (JSON). Rueckgabe: 1 = fehlt, 2 = mehrdeutig
op_field() {
    local item="$1" label="$2" json
    json=$(op item get "$item" --format json 2>/dev/null) || return 1
    printf '%s' "$json" | python3 -c '
import sys, json
label = sys.argv[1]
data = json.load(sys.stdin)
vals = [f.get("value") for f in data.get("fields", []) if f.get("label") == label and f.get("value")]
if not vals:
    sys.exit(1)
if len(vals) > 1:
    sys.exit(2)
print(vals[0])
' "$label"
}

UNI_DATA_OK=1
if ! op read "op://University/Mac-Setup Uni/uni/ldap_host" >/dev/null 2>&1; then
    UNI_DATA_OK=0
    warn_setup "1Password item 'Mac-Setup Uni' (vault University) not readable - Uni templates (WireGuard peers, LDAP, SSH alias) skipped. Unlock 1Password, enable 'Integrate with 1Password CLI', then rerun ./setup.sh"
fi

# ----------------------------
# ssh config
# ----------------------------

echo "Installing SSH config..."

mkdir -p "$HOME/.ssh/config.d"
chmod 700 "$HOME/.ssh"

if [ ! -f "$HOME/.ssh/config" ]; then
    cp "$REPO/ssh/config" "$HOME/.ssh/config"
elif ! grep -q '^Include ~/.ssh/config.d/\*' "$HOME/.ssh/config"; then
    # Include muss vor allen Host-Bloecken stehen
    { printf 'Include ~/.ssh/config.d/*\n\n'; cat "$HOME/.ssh/config"; } > "$HOME/.ssh/config.new"
    mv "$HOME/.ssh/config.new" "$HOME/.ssh/config"
    echo "Added Include for ~/.ssh/config.d to existing SSH config."
else
    echo "SSH config already exists – Include present."
fi
chmod 600 "$HOME/.ssh/config"

# Alias "uni" (Host/User aus 1Password)
if [ "$UNI_DATA_OK" = 1 ]; then
    if SSH_UNI=$(op inject -i "$REPO/templates/ssh-uni.conf.tpl" 2>/dev/null); then
        printf '%s\n' "$SSH_UNI" > "$HOME/.ssh/config.d/uni.conf"
        chmod 600 "$HOME/.ssh/config.d/uni.conf"
        echo "→ ssh alias 'uni' written to ~/.ssh/config.d/uni.conf"
    else
        warn_setup "SSH alias 'uni' not written (op inject failed for templates/ssh-uni.conf.tpl - check field names in 'Mac-Setup Uni')"
    fi
fi

# ----------------------------
# Claude Code (lokales CLI)
# ----------------------------
# Nativer Installer von Anthropic (aktualisiert sich selbst). Idempotent:
# nur wenn `claude` weder im PATH noch in ~/.local/bin liegt.

if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
    echo "Claude Code already installed."
else
    echo "Installing Claude Code..."
    CC_TMP="$(mktemp)"
    if curl -fsSL https://claude.ai/install.sh -o "$CC_TMP" && bash "$CC_TMP"; then
        echo "Claude Code installed."
    else
        warn_setup "Claude Code konnte nicht installiert werden (manuell: curl -fsSL https://claude.ai/install.sh | bash)"
    fi
    rm -f "$CC_TMP"
fi

# ----------------------------
# Claude Code Berechtigungen (claude/settings.json)
# ----------------------------
# Sperrt op read/item get, ~/.ssh und die Verbotsliste fuer Claude; fragt bei
# push/rm/sudo nach. Vorhandene, abweichende Datei wird nicht ueberschrieben.

CC_SRC="$REPO/claude/settings.json"
CC_DST="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
if [ -L "$CC_DST" ] || [ ! -e "$CC_DST" ]; then
    ln -sfn "$CC_SRC" "$CC_DST"
    echo "Claude Code settings linked."
elif [ "$CC_DST" -ef "$CC_SRC" ]; then
    :
else
    warn_setup "~/.claude/settings.json existiert bereits und wurde nicht ersetzt (Regeln aus $CC_SRC manuell uebernehmen)"
fi

# ----------------------------
# Git pre-commit hook (verhindert, dass Uni-Daten/Schluessel ins Repo kommen)
# ----------------------------
# Der Hook liegt im Repo (hooks/), die Verbotsliste mit echten Werten NICHT:
# sie wird aus 1Password nach ~/.config/mac-setup/forbidden.txt erzeugt.

echo "Installing git pre-commit hook..."
chmod +x "$REPO/hooks/pre-commit" "$REPO/hooks/update-forbidden.sh"
git -C "$REPO" config core.hooksPath hooks

if [ "$UNI_DATA_OK" = 1 ]; then
    if ! bash "$REPO/hooks/update-forbidden.sh"; then
        warn_setup "Forbidden-terms list for the pre-commit hook not created (hooks/update-forbidden.sh failed)"
    fi
else
    warn_setup "Forbidden-terms list not created (1Password not readable) - pre-commit hook only checks generic patterns. Rerun ./setup.sh or: bash ~/mac-setup/hooks/update-forbidden.sh"
fi

# ----------------------------
# wireguard environment
# ----------------------------

echo ""
echo "WireGuard configuration (role: $MAC_ROLE)"

case "$MAC_ROLE" in
    uni)    WG_ENV="u" ;;
    privat) WG_ENV="p" ;;
esac

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
# Peer-Daten (PublicKey/Endpoint/AllowedIPs) kommen per `op inject` aus dem
# gemeinsamen Item "Mac-Setup Uni", PrivateKey/Address aus dem Item dieses Macs.

echo "Installing WireGuard configs..."

WG_SRC="$REPO/templates"
WG_DST="/opt/homebrew/etc/wireguard"

sudo mkdir -p "$WG_DST"

for tpl in "$WG_SRC"/wg-*.conf.tpl; do
    [ -f "$tpl" ] || continue

    fname=$(basename "$tpl" .tpl)     # z.B. wg-fim5.conf

    case "$fname" in
        wg-fim5.conf)  ITEM="$WG_FIM_ITEM" ;;
        wg-faith.conf) ITEM="$WG_FAITH_ITEM" ;;
        *)
            warn_setup "No 1Password item mapped for $fname - skipped"
            continue
            ;;
    esac

    if [ "$UNI_DATA_OK" != 1 ]; then
        warn_setup "$fname skipped (Uni data not available)"
        continue
    fi

    KEY=$(op_field "$ITEM" private) && rc=0 || rc=$?
    case $rc in
        0) ;;
        2) warn_setup "$fname skipped: item '$ITEM' has more than one 'private' field - remove the old one"; continue ;;
        *) warn_setup "$fname skipped: field 'private' missing in item '$ITEM'"; continue ;;
    esac

    IP=$(op_field "$ITEM" address) && rc=0 || rc=$?
    case $rc in
        0) ;;
        2) warn_setup "$fname skipped: item '$ITEM' has more than one 'address' field"; continue ;;
        *) warn_setup "$fname skipped: field 'address' missing in item '$ITEM'"; continue ;;
    esac

    RENDERED=$(op inject -i "$tpl" 2>/dev/null) && rc=0 || rc=$?
    if [ "$rc" -ne 0 ]; then
        warn_setup "$fname skipped: op inject failed (check field names in 'Mac-Setup Uni')"
        continue
    fi

    printf '%s\n' "$RENDERED" \
        | sed -e "s|<ENTER_PRIVATE_KEY_HERE>|$KEY|" \
              -e "s|<ENTER_IP_ADDRESS_HERE>|$IP|" \
        | sudo tee "$WG_DST/$fname" > /dev/null
    sudo chmod 600 "$WG_DST/$fname"
    echo "→ $fname installed"
done
unset KEY IP RENDERED

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

# connections.xml (Host, Port, Bind-DN) kommt aus 1Password
if [ "$UNI_DATA_OK" = 1 ]; then
    CONN_DIR="$LDAP_DST/org.apache.directory.studio.connection.core"
    mkdir -p "$CONN_DIR"
    if LDAP_XML=$(op inject -i "$REPO/templates/ldap-connections.xml.tpl" 2>/dev/null); then
        printf '%s\n' "$LDAP_XML" > "$CONN_DIR/connections.xml"
        chmod 600 "$CONN_DIR/connections.xml"
        echo "→ LDAP connection written"
    else
        warn_setup "LDAP connections.xml not written (op inject failed - check field names in 'Mac-Setup Uni')"
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

# Das Wallpaper liegt nicht mehr im Repo (20 MB), sondern in iCloud Drive:
#  1. Documents/wallpaper/wallpaper-freizeit.jpg (wie von mode.sh genutzt)
#  2. iCloud Drive/bootstrap/wallpaper.jpg (liegt neben mac-bootstrap.sh und ist
#     auf einem frisch installierten Mac frueher da als der Documents-Ordner)
WALLPAPER=""
for candidate in \
    "$HOME/Documents/wallpaper/wallpaper-freizeit.jpg" \
    "$HOME/Library/Mobile Documents/com~apple~CloudDocs/bootstrap/wallpaper.jpg"
do
    if [ -f "$candidate" ]; then
        WALLPAPER="$candidate"
        break
    fi
done

if [ -n "$WALLPAPER" ]; then
    sleep 2

    osascript <<EOF
tell application "System Events"
    repeat with d in desktops
        set picture of d to "$WALLPAPER"
    end repeat
end tell
EOF
else
    echo "No wallpaper found (looked in ~/Documents/wallpaper and iCloud Drive/bootstrap)."
    echo "(iCloud Drive may not have synced yet - 'mode freizeit' sets it later.)"
fi

# ----------------------------
# Warnings collected during setup
# ----------------------------

if [ "${#SETUP_WARNINGS[@]}" -gt 0 ]; then
    echo ""
    echo "=================================================="
    echo "Setup finished with warnings:"
    for w in "${SETUP_WARNINGS[@]}"; do
        echo " - $w"
    done
    echo "=================================================="
fi

# ----------------------------
# Manual follow-ups (macOS privacy / TCC)
# ----------------------------

echo ""
echo "--------------------------------------------------"
echo "Manual steps for the background agents"
echo ""
echo "1) Downloads watcher: grant /bin/bash"
echo "   System Settings > Privacy & Security > Full Disk Access > + > /bin/bash"
if [ "$MAC_ROLE" = "privat" ]; then
echo ""
echo "2) Calendar sync: run once in a terminal to grant calendar access:"
echo "   uv run --script ~/bin/sync_calendars.py --dry-run"
fi
echo "--------------------------------------------------"
echo ""

# ----------------------------
# Finished
# ----------------------------

echo ""
echo "Setup complete. Import README to Apple Notes..."
echo ""

sleep 2
open -a Notes "$REPO/README.md" 2>/dev/null || true
sleep 5
open -a Notes "$REPO/POST-INSTALL.md" 2>/dev/null || true
