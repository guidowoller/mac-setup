#!/bin/bash

echo ""
echo "Running mac setup doctor..."
echo ""

PASS=0
FAIL=0

ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }
warn() { echo "⚠ $1"; }

# ----------------------------
# Homebrew
# ----------------------------

if command -v brew >/dev/null 2>&1; then
    ok "Homebrew installed"
else
    fail "Homebrew missing"
fi

# ----------------------------
# Important CLI tools
# ----------------------------

for cmd in tmux fzf eza starship wg nvim zoxide yazi autossh fswatch uv; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd installed"
    else
        fail "$cmd missing"
    fi
done

# ----------------------------
# 1Password SSH agent
# ----------------------------

AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

if [ -S "$AGENT_SOCK" ]; then
    ok "1Password SSH agent socket exists"
else
    fail "1Password SSH agent socket missing (1Password not running or SSH agent not enabled)"
fi

if SSH_AUTH_SOCK="$AGENT_SOCK" ssh-add -l >/dev/null 2>&1; then
    KEY_COUNT=$(SSH_AUTH_SOCK="$AGENT_SOCK" ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
    ok "1Password SSH agent loaded ($KEY_COUNT key(s))"
else
    fail "1Password SSH agent has no keys loaded"
fi

# ----------------------------
# Starship config
# ----------------------------

if [ -f "$HOME/.config/starship.toml" ]; then
    ok "Starship config exists"
else
    fail "Starship config missing (~/.config/starship.toml)"
fi

# ----------------------------
# Neovim config
# ----------------------------

if [ -L "$HOME/.config/nvim" ]; then
    ok "Neovim config symlinked"
elif [ -d "$HOME/.config/nvim" ]; then
    warn "Neovim config exists but is not a symlink (run setup.sh to fix)"
else
    fail "Neovim config missing"
fi

# ----------------------------
# Dotfile symlinks
# ----------------------------

for df in .zshrc .vimrc .nanorc .tmux.conf .gitconfig; do
    if [ -L "$HOME/$df" ]; then
        ok "$df symlinked"
    elif [ -f "$HOME/$df" ]; then
        warn "$df exists but is not a symlink"
    else
        fail "$df missing"
    fi
done

# ----------------------------
# Rolle dieses Macs
# ----------------------------

MAC_ROLE=""
if [ -f "$HOME/.mac-role" ]; then
    MAC_ROLE=$(tr -d '[:space:]' < "$HOME/.mac-role")
    ok "Mac role: $MAC_ROLE"
else
    fail "~/.mac-role missing (run setup.sh)"
fi

# ----------------------------
# ~/bin scripts
# ----------------------------

if [ -d "$HOME/bin" ]; then
    ok "~/bin exists"
    BIN_SCRIPTS="mode.sh vpn.sh ms365.sh a.sh ap.sh close-all-apps.sh sync_downloads.sh watch_downloads.sh"
    [ "$MAC_ROLE" = "privat" ] && BIN_SCRIPTS="$BIN_SCRIPTS ms365sync-run.sh sync_calendars.py"
    for script in $BIN_SCRIPTS; do
        if [ -f "$HOME/bin/$script" ]; then
            ok "  ~/bin/$script"
        else
            fail "  ~/bin/$script missing"
        fi
    done
else
    fail "~/bin missing"
fi

# ----------------------------
# WireGuard
# ----------------------------

WG_DIR="/opt/homebrew/etc/wireguard"

if [ -d "$WG_DIR" ]; then
    ok "WireGuard config directory exists"
    for conf in wg-fim5.conf wg-faith.conf; do
        if [ -f "$WG_DIR/$conf" ]; then
            # Sicherstellen dass kein Placeholder mehr drin ist.
            # Die Dateien gehoeren root (chmod 600): ohne Leserecht kann das
            # nicht geprueft werden -> Warnung statt falschem "ok".
            grep -q -E '<ENTER_|\{\{|op://' "$WG_DIR/$conf" 2>/dev/null
            case $? in
                0) fail "  $conf contains unfilled placeholders!" ;;
                1) ok   "  $conf present and filled" ;;
                *) warn "  $conf present, but not readable without sudo (placeholders not checked; try: sudo grep -c -E '<ENTER_|op://' $WG_DIR/$conf)" ;;
            esac
        else
            fail "  $conf missing"
        fi
    done
else
    fail "WireGuard config directory missing ($WG_DIR)"
fi

# ----------------------------
# Uni-Vorlagen (aus 1Password erzeugt)
# ----------------------------

SSH_UNI_CONF="$HOME/.ssh/config.d/uni.conf"
if [ -f "$SSH_UNI_CONF" ]; then
    if grep -q -E '\{\{|op://' "$SSH_UNI_CONF"; then
        fail "ssh alias file contains unfilled references ($SSH_UNI_CONF)"
    else
        ok "ssh alias 'uni' present and filled"
    fi
else
    fail "ssh alias file missing ($SSH_UNI_CONF) - rerun setup.sh with 1Password unlocked"
fi

if grep -q '^Include ~/.ssh/config.d/\*' "$HOME/.ssh/config" 2>/dev/null; then
    ok "~/.ssh/config includes config.d"
else
    fail "~/.ssh/config has no 'Include ~/.ssh/config.d/*' (alias 'uni' not active)"
fi

LDAP_CONN="$HOME/eclipse-workspace/.metadata/.plugins/org.apache.directory.studio.connection.core/connections.xml"
if [ -f "$LDAP_CONN" ]; then
    if grep -q -E '\{\{|op://' "$LDAP_CONN"; then
        fail "LDAP connections.xml contains unfilled references"
    else
        ok "LDAP connection present and filled"
    fi
else
    warn "LDAP connections.xml not found ($LDAP_CONN) - Directory Studio plugin installed / setup.sh run?"
fi

# ----------------------------
# VS Code CLI
# ----------------------------

if command -v code >/dev/null 2>&1; then
    ok "VS Code CLI available"
else
    fail "VS Code CLI missing"
fi

# ----------------------------
# LaunchAgents
# ----------------------------

check_agent() {
    local label="$1"
    local plist="$HOME/Library/LaunchAgents/$label.plist"

    if [ -f "$plist" ]; then
        ok "$label plist installed"
    else
        fail "$label plist missing ($plist)"
        return
    fi

    if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
        ok "$label LaunchAgent loaded"
    else
        fail "$label LaunchAgent not loaded"
    fi
}

# Downloads-Watcher: auf allen Macs
check_agent com.guido.downloadsync

if launchctl print "gui/$(id -u)/com.guido.downloadsync" 2>/dev/null | grep -q "state = running"; then
    ok "downloadsync watcher running"
else
    fail "downloadsync watcher not running"
fi

DL_LOG="$HOME/Library/Logs/downloads-sync.log"
if [ -f "$DL_LOG" ] && grep -q "FEHLER" "$DL_LOG"; then
    warn "downloads-sync.log contains errors (last: $(grep FEHLER "$DL_LOG" | tail -n1))"
fi

# Kalender-Sync: nur auf dem privaten Mac
if [ "$MAC_ROLE" = "privat" ]; then
    check_agent com.guido.ms365sync

    LOG_OUT="$HOME/Library/Logs/ms365sync.out.log"
    if [ -f "$LOG_OUT" ]; then
        LAST=$(grep "ms365sync:" "$LOG_OUT" 2>/dev/null | tail -n1)
        if [ -z "$LAST" ]; then
            warn "ms365sync log exists but no runs recorded yet"
        elif echo "$LAST" | grep -q "ms365sync: OK"; then
            ok "ms365sync last run: $(echo "$LAST" | awk '{print $1}')"
        else
            fail "ms365sync last run failed: $LAST"
        fi
    else
        warn "ms365sync has never run (no log file)"
    fi
elif [ -f "$HOME/Library/LaunchAgents/com.guido.ms365sync.plist" ]; then
    fail "ms365sync agent is installed on a non-private Mac (should only run on the private one)"
fi

# ----------------------------
# GitHub SSH
# ----------------------------

if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    ok "GitHub SSH authentication works"
else
    warn "GitHub SSH not available (VPN required, or key not loaded)"
fi

# ----------------------------
# Summary
# ----------------------------

echo ""
echo "----------------------------"
echo "✓ $PASS passed   ✗ $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
