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

for cmd in tmux fzf eza starship wg nvim zoxide yazi autossh; do
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
# ~/bin scripts
# ----------------------------

if [ -d "$HOME/bin" ]; then
    ok "~/bin exists"
    for script in mode.sh vpn.sh ms365.sh ms365sync.scpt a.sh ap.sh close-all-apps.sh; do
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
            # Sicherstellen dass kein Placeholder mehr drin ist
            if grep -q "<ENTER_" "$WG_DIR/$conf"; then
                fail "  $conf contains unfilled placeholders!"
            else
                ok "  $conf present and filled"
            fi
        else
            fail "  $conf missing"
        fi
    done
else
    fail "WireGuard config directory missing ($WG_DIR)"
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
# LaunchAgent: ms365sync
# ----------------------------

PLIST="$HOME/Library/LaunchAgents/com.guido.ms365sync.plist"

if [ -f "$PLIST" ]; then
    ok "ms365sync plist installed"
else
    fail "ms365sync plist missing ($PLIST)"
fi

if launchctl list | grep -q "com.guido.ms365sync"; then
    ok "ms365sync LaunchAgent loaded"
else
    fail "ms365sync LaunchAgent not loaded"
fi

LOG_OUT="$HOME/Library/Logs/ms365sync.out.log"
if [ -f "$LOG_OUT" ]; then
    LAST=$(grep "ms365sync:" "$LOG_OUT" 2>/dev/null | tail -n1)
    if [ -n "$LAST" ]; then
        ok "ms365sync last run: $(echo "$LAST" | awk '{print $1}')"
    else
        warn "ms365sync log exists but no runs recorded yet"
    fi
else
    warn "ms365sync has never run (no log file)"
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
