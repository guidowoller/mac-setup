#!/bin/bash
#
# brewcheck.sh - vergleicht dieses System mit dem Brewfile (Drift bei Paketen)
#
#   brewcheck.sh          Bericht (Exit-Code 1, wenn es Abweichungen gibt)
#   brewcheck.sh --add    fehlende Eintraege interaktiv ins Brewfile uebernehmen
#                         (deinstalliert NIE etwas)
#
# 1. "Im Brewfile, aber nicht installiert (oder veraltet)" -> brew bundle check
#    (brew meldet beides mit "needs to be installed or updated")
# 2. "Installiert, aber nicht im Brewfile"  -> brew bundle cleanup (Trockenlauf;
#    beruecksichtigt Aliase und Abhaengigkeiten)
# Pakete, die bewusst nur auf einem Mac liegen sollen, koennen in
# ~/.config/mac-setup/brew-ignore.txt stehen (ein Name pro Zeile, nicht im Repo).
# macOS-kompatibel (bash 3.2).

REPO="${MAC_SETUP_REPO:-$HOME/mac-setup}"
BREWFILE="$REPO/Brewfile"
IGNORE="${BREW_IGNORE_FILE:-$HOME/.config/mac-setup/brew-ignore.txt}"
TTY_IN="${BREWCHECK_TTY:-/dev/tty}"
MODE="${1:-report}"

export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1

BREW="$(command -v brew 2>/dev/null)"
[ -n "$BREW" ] || { [ -x /opt/homebrew/bin/brew ] && BREW=/opt/homebrew/bin/brew; }
[ -n "$BREW" ] || { echo "brew nicht gefunden" >&2; exit 2; }
[ -f "$BREWFILE" ] || { echo "Brewfile nicht gefunden: $BREWFILE" >&2; exit 2; }
case "$MODE" in report|--add) ;; *) echo "Aufruf: brewcheck.sh [--add]" >&2; exit 2 ;; esac

# ---------------- 1. fehlt auf diesem Mac ----------------
CHECK_OUT=$("$BREW" bundle check --file "$BREWFILE" --verbose 2>&1)
CHECK_RC=$?
MISSING=$(printf '%s\n' "$CHECK_OUT" | grep -E '^[[:space:]]*(→|->)' \
          | sed -E 's/^[[:space:]]*(→|->)[[:space:]]*//' || true)

# ---------------- 2. installiert, aber nicht im Brewfile ----------------
CLEAN_OUT=$("$BREW" bundle cleanup --file "$BREWFILE" 2>&1 || true)

# Ausgabe in Zeilen "art name" umwandeln (art: brew, cask, tap). Funktioniert fuer
# die aeltere ("Would uninstall formulae:") und neuere ("Would `brew uninstall ...`:")
# Formatierung, auch wenn mehrere Namen pro Zeile stehen.
EXTRAS=$(printf '%s\n' "$CLEAN_OUT" | awk '
    /^Run / { kind = ""; next }
    /^Would/ {
        kind = ""
        if ($0 ~ /cask/)         kind = "cask"
        else if ($0 ~ /formula/) kind = "brew"
        else if ($0 ~ /tap/)     kind = "tap"
        next
    }
    kind != "" && NF > 0 { for (i = 1; i <= NF; i++) print kind, $i }
')

if [ -f "$IGNORE" ] && [ -n "$EXTRAS" ]; then
    EXTRAS=$(printf '%s\n' "$EXTRAS" | awk 'NR==FNR { if ($1 !~ /^#/ && NF) ig[$1]=1; next } !($2 in ig)' "$IGNORE" -)
fi

# ---------------- --add ----------------
insert_entry() {   # $1 = art, $2 = zeile
    local kind="$1" line="$2" n tmp
    n=$(grep -n "^$kind \"" "$BREWFILE" | tail -n 1 | cut -d: -f1)
    tmp=$(mktemp)
    if [ -n "$n" ]; then
        awk -v n="$n" -v line="$line" '{ print } NR == n { print line }' "$BREWFILE" > "$tmp"
    elif [ "$kind" = "tap" ]; then
        { echo "$line"; cat "$BREWFILE"; } > "$tmp"
    else
        { cat "$BREWFILE"; echo "$line"; } > "$tmp"
    fi
    cat "$tmp" > "$BREWFILE"
    rm -f "$tmp"
}

if [ "$MODE" = "--add" ]; then
    if [ -z "$EXTRAS" ]; then
        echo "Nichts zu übernehmen: alles Installierte steht im Brewfile."
        exit 0
    fi
    ADDED=0
    exec 3< "$TTY_IN" || { echo "Keine Eingabe möglich ($TTY_IN)" >&2; exit 2; }
    while read -r kind name; do
        [ -n "$name" ] || continue
        printf '%s "%s" ins Brewfile aufnehmen? [y/N/q] ' "$kind" "$name"
        read -r ans <&3 || break
        case "$ans" in
            y|Y) insert_entry "$kind" "$kind \"$name\""; ADDED=$((ADDED+1)); echo "  → aufgenommen" ;;
            q|Q) break ;;
            *)   echo "  → übersprungen" ;;
        esac
    done <<< "$EXTRAS"
    echo ""
    echo "$ADDED Eintrag/Einträge hinzugefügt."
    [ "$ADDED" -gt 0 ] && echo "Danach committen: cd $REPO && git add Brewfile && git commit && git push"
    exit 0
fi

# ---------------- Bericht ----------------
RC=0
echo "Brewfile: $BREWFILE"

if [ -n "$MISSING" ]; then
    RC=1
    echo "⚠ Im Brewfile, aber hier nicht installiert oder veraltet (fehlt: brew bundle install, veraltet: upgrade):"
    printf '%s\n' "$MISSING" | sed 's/^/    /'
elif [ "$CHECK_RC" -ne 0 ]; then
    RC=1
    echo "⚠ brew bundle check meldet ein Problem:"
    printf '%s\n' "$CHECK_OUT" | sed 's/^/    /'
else
    echo "✔ alles aus dem Brewfile ist installiert"
fi

if [ -n "$EXTRAS" ]; then
    RC=1
    echo "⚠ Installiert, aber nicht im Brewfile:"
    printf '%s\n' "$EXTRAS" | while read -r kind name; do echo "    $kind \"$name\""; done
    echo "    → aufnehmen: brewcheck.sh --add   |   entfernen: brew uninstall <name>"
    echo "    → bewusst nur hier: Name in $IGNORE eintragen"
else
    echo "✔ nichts installiert, was nicht im Brewfile steht"
fi
exit $RC
