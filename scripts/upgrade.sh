#!/bin/bash
#
# upgrade.sh - holt diesen Mac auf den Stand von mac-setup und haelt ihn aktuell
#
#   upgrade.sh           mac-setup pullen, Homebrew aktualisieren, Brewfile anwenden,
#                        fehlende ~/bin-Links anlegen, macOS-Updates anzeigen
#   upgrade.sh --check   nur anzeigen, nichts veraendern (Drift, Brewfile, veraltete
#                        Pakete, macOS-Updates)
#
# Gegenstueck zu update.sh: update.sh bringt DEINE lokale Konfiguration ins Repo
# (Backup, Commit, Push); upgrade.sh holt den Stand aus dem Repo und aktualisiert Software.
# Macht nichts Riskantes von allein: kein macOS-Update installieren, kein setup.sh,
# nichts deinstallieren. macOS-kompatibel (bash 3.2).

REPO="${MAC_SETUP_REPO:-$HOME/mac-setup}"
BIN_DIR="$HOME/bin"
MODE="${1:-run}"
case "$MODE" in run|--check) ;; *) echo "Aufruf: upgrade.sh [--check]" >&2; exit 2 ;; esac

[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

RESULTS=()
HINTS=()
FAIL=0
step_ok()   { RESULTS+=("✔ $1"); }
step_warn() { RESULTS+=("⚠ $1"); }
step_fail() { RESULTS+=("✖ $1"); FAIL=1; }
header()    { echo ""; echo "━━ $1"; }

HAVE_BREW=0; command -v brew >/dev/null 2>&1 && HAVE_BREW=1

# ---------------- --check: nur lesen ----------------
if [ "$MODE" = "--check" ]; then
    header "mac-setup vs. GitHub"
    if [ -x "$REPO/scripts/drift.sh" ]; then "$REPO/scripts/drift.sh" && step_ok "mac-setup" || step_warn "mac-setup (Drift)"; fi

    if [ "$HAVE_BREW" -eq 1 ]; then
        header "Brewfile"
        if [ -x "$REPO/scripts/brewcheck.sh" ]; then "$REPO/scripts/brewcheck.sh" && step_ok "Brewfile" || step_warn "Brewfile (Abweichungen)"; fi
        header "Veraltete Pakete"
        OUTDATED=$(brew outdated 2>/dev/null)
        if [ -n "$OUTDATED" ]; then echo "$OUTDATED"; step_warn "Homebrew: veraltete Pakete"; else echo "alles aktuell"; step_ok "Homebrew aktuell"; fi
    fi

    header "macOS-Updates"
    SU=$(softwareupdate -l 2>&1)
    echo "$SU"
    if echo "$SU" | grep -q "No new software available"; then step_ok "macOS aktuell"; else step_warn "macOS: Updates verfuegbar oder Abfrage nicht moeglich"; fi

    echo ""; echo "══ Zusammenfassung (--check, nichts veraendert)"
    for r in "${RESULTS[@]}"; do echo "  $r"; done
    exit 0
fi

# ---------------- 1. mac-setup pullen ----------------
header "mac-setup aktualisieren"
CHANGED=""
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
        echo "Lokale Aenderungen an getrackten Dateien - kein Pull (erst committen/pushen, z.B. update.sh)."
        step_warn "mac-setup nicht gepullt (lokale Aenderungen)"
    else
        OLD=$(git -C "$REPO" rev-parse HEAD)
        if git -C "$REPO" pull --ff-only; then
            NEW=$(git -C "$REPO" rev-parse HEAD)
            if [ "$OLD" != "$NEW" ]; then
                CHANGED=$(git -C "$REPO" diff --name-only "$OLD" "$NEW")
                step_ok "mac-setup gepullt ($(echo "$CHANGED" | grep -c .) Datei(en) geaendert)"
            else
                step_ok "mac-setup bereits aktuell"
            fi
        else
            step_fail "git pull --ff-only fehlgeschlagen (divergiert? Offline? -> git status / git pull --rebase)"
        fi
    fi
else
    step_fail "$REPO ist kein Git-Repo"
fi

# ---------------- 2. Homebrew ----------------
if [ "$HAVE_BREW" -eq 1 ]; then
    header "Homebrew aktualisieren"
    if brew update && brew upgrade && brew upgrade --cask && brew cleanup -s; then
        step_ok "Homebrew aktualisiert"
    else
        step_fail "Homebrew-Update (siehe Ausgabe oben; brew doctor)"
    fi

    header "Brewfile anwenden (fehlende Pakete installieren, nichts upgraden)"
    if [ -f "$REPO/Brewfile" ]; then
        if brew bundle --file "$REPO/Brewfile" --no-upgrade; then
            step_ok "Brewfile angewendet"
        else
            step_fail "brew bundle fehlgeschlagen"
        fi
    fi
else
    step_warn "Homebrew nicht gefunden - uebersprungen"
fi

# ---------------- 3. ~/bin-Links fuer neue Skripte ----------------
header "Skript-Links in ~/bin"
mkdir -p "$BIN_DIR"
LINKED=0
MODE_CHANGED=""
for f in "$REPO"/scripts/*.sh "$REPO"/scripts/*.py; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    if [ ! -x "$f" ]; then
        chmod +x "$f" 2>/dev/null && MODE_CHANGED="$MODE_CHANGED $name"
    fi
    if [ ! -e "$BIN_DIR/$name" ] && [ ! -L "$BIN_DIR/$name" ]; then
        ln -s "$f" "$BIN_DIR/$name" && { echo "→ neu verlinkt: $name"; LINKED=$((LINKED+1)); }
    fi
done
[ "$LINKED" -eq 0 ] && echo "keine neuen Skripte"
step_ok "Skript-Links ($LINKED neu)"
if [ -n "$MODE_CHANGED" ]; then
    HINTS+=("Ausfuehrbar-Bit gesetzt fuer:$MODE_CHANGED - im Repo fehlte es. Committen (cd $REPO && git add -A && git commit && git push), sonst gilt der Baum als geaendert und der naechste Pull wird uebersprungen")
fi

# ---------------- 4. macOS-Updates (nur anzeigen) ----------------
header "macOS-Updates (nur Anzeige)"
SU=$(softwareupdate -l 2>&1)
echo "$SU"
if echo "$SU" | grep -q "No new software available"; then
    step_ok "macOS aktuell"
else
    step_warn "macOS: Updates verfuegbar oder Abfrage nicht moeglich (installieren: sudo softwareupdate -ia)"
fi

# ---------------- Hinweise nach einem Pull ----------------
if [ -n "$CHANGED" ]; then
    if echo "$CHANGED" | grep -q -E '^(setup\.sh|templates/|launchagents/|hooks/|ssh/|macos/)'; then
        HINTS+=("Setup-relevante Dateien haben sich geaendert -> ./setup.sh erneut ausfuehren (aus Terminal.app)")
    fi
    if echo "$CHANGED" | grep -q -E '^dotfiles/\.zshrc'; then
        HINTS+=("Shell-Konfiguration geaendert -> neuen iTerm-Tab oeffnen")
    fi
fi

# ---------------- Zusammenfassung ----------------
echo ""
echo "══ Zusammenfassung"
for r in "${RESULTS[@]}"; do echo "  $r"; done
if [ "${#HINTS[@]}" -gt 0 ]; then
    echo ""
    for h in "${HINTS[@]}"; do echo "  → $h"; done
fi
echo ""
echo "  Danach pruefen: doctor"
exit $FAIL
