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
    BIN_SCRIPTS="mode.sh vpn.sh ms365.sh a.sh ap.sh close-all-apps.sh sync_downloads.sh watch_downloads.sh drift.sh brewcheck.sh histsync.sh upgrade.sh"
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
# Shell-History-Sync (iCloud)
# ----------------------------

HIST_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/shell-history"
HIST_HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
if [ -d "$HIST_DIR" ]; then
    ok "iCloud history folder exists"
    if [ -f "$HIST_DIR/$HIST_HOST.zsh_history" ]; then
        ok "own history file published ($HIST_HOST.zsh_history)"
    else
        warn "own history file not in iCloud yet (open a new iTerm tab or run: histsync push)"
    fi
    HIST_OTHERS=$(ls "$HIST_DIR" 2>/dev/null | grep -c '\.zsh_history$')
    [ "$HIST_OTHERS" -gt 1 ] && ok "history files of other Macs present" \
        || warn "no history file of another Mac yet (nothing to merge)"
else
    warn "iCloud history folder missing (created on first iTerm shell start with histsync)"
fi
if [ -f "$HOME/.zsh_history" ] && grep -q -E '^: [0-9]+:[0-9]+;' "$HOME/.zsh_history"; then
    ok "local history has timestamps (EXTENDED_HISTORY)"
else
    warn "local history has no timestamps yet (new entries get them once .zshrc.iterm is loaded)"
fi

# ----------------------------
# Brewfile (installierte Pakete vs. Brewfile)
# ----------------------------

if [ -x "$(dirname "$0")/scripts/brewcheck.sh" ] && command -v brew >/dev/null 2>&1; then
    if BREW_OUT=$("$(dirname "$0")/scripts/brewcheck.sh" 2>&1); then
        ok "Brewfile matches installed packages"
    else
        warn "Brewfile drift detected (details: brewcheck):"
        echo "$BREW_OUT" | sed 's/^/        /'
    fi
fi

# ----------------------------
# Drift (mac-setup vs. GitHub)
# ----------------------------

if [ -x "$(dirname "$0")/scripts/drift.sh" ]; then
    if DRIFT_OUT=$("$(dirname "$0")/scripts/drift.sh" 2>&1); then
        ok "mac-setup in sync with GitHub, no local changes"
    else
        warn "mac-setup drift detected:"
        echo "$DRIFT_OUT" | sed 's/^/        /'
    fi
else
    warn "scripts/drift.sh missing"
fi

# ----------------------------
# Git pre-commit hook
# ----------------------------

DOCTOR_REPO="$(cd "$(dirname "$0")" && pwd)"
HOOKS_PATH=$(git -C "$DOCTOR_REPO" config core.hooksPath 2>/dev/null || true)
if [ "$HOOKS_PATH" = "hooks" ]; then
    ok "git core.hooksPath = hooks"
else
    fail "git core.hooksPath not set to 'hooks' (rerun setup.sh or: git -C $DOCTOR_REPO config core.hooksPath hooks)"
fi

if [ -x "$DOCTOR_REPO/hooks/pre-commit" ]; then
    ok "hooks/pre-commit is executable"
else
    fail "hooks/pre-commit missing or not executable (chmod +x hooks/pre-commit)"
fi

FORBIDDEN="$HOME/.config/mac-setup/forbidden.txt"
if [ -s "$FORBIDDEN" ]; then
    N_TERMS=$(grep -c . "$FORBIDDEN")
    if [ "$N_TERMS" -ge 5 ]; then
        ok "forbidden-terms list present ($N_TERMS terms)"
    else
        warn "forbidden-terms list has only $N_TERMS terms (bash $DOCTOR_REPO/hooks/update-forbidden.sh)"
    fi

    # Selbsttest: sauberer Commit muss durchgehen, einer mit verbotenem Begriff muss scheitern
    HT_DIR="$(mktemp -d)"
    HT_TERM="$(grep -v '^#' "$FORBIDDEN" | grep . | head -n 1)"
    (
        cd "$HT_DIR" && git init -q . \
            && git config user.name doctor && git config user.email doctor@localhost \
            && git config core.hooksPath "$DOCTOR_REPO/hooks" \
            && git commit -q --allow-empty -m init >/dev/null 2>&1
    )
    echo "harmless line" > "$HT_DIR/clean.txt"
    ( cd "$HT_DIR" && git add clean.txt && git commit -q -m clean >/dev/null 2>&1 ); CLEAN_RC=$?
    printf '%s\n' "$HT_TERM" > "$HT_DIR/dirty.txt"
    ( cd "$HT_DIR" && git add dirty.txt && git commit -q -m dirty >/dev/null 2>&1 ); DIRTY_RC=$?
    rm -rf "$HT_DIR"
    if [ "$CLEAN_RC" -eq 0 ] && [ "$DIRTY_RC" -ne 0 ]; then
        ok "pre-commit self-test (clean passes, forbidden term blocked)"
    else
        fail "pre-commit self-test failed (clean rc=$CLEAN_RC, forbidden rc=$DIRTY_RC)"
    fi
else
    warn "forbidden-terms list missing ($FORBIDDEN) - run: bash $DOCTOR_REPO/hooks/update-forbidden.sh (needs 1Password)"
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
