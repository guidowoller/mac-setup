#!/bin/bash
#
# drift.sh - zeigt, ob dieser Mac vom Stand des mac-setup-Repos abweicht
#
#   drift.sh            vollstaendiger Bericht mit frischer Abfrage bei GitHub
#                       (Exit-Code 1, wenn es Abweichungen gibt)
#   drift.sh --prompt   leise: nur Warnungen, aus lokalem Stand + Cache. Ist der
#                       Cache aelter als 30 Minuten, wird im Hintergrund aktualisiert.
#                       Fuer die Shell-Startdatei gedacht - blockiert nie.
#   drift.sh --refresh  nur den Cache aktualisieren (intern)
#
# Geprueft wird: lokale Aenderungen nicht committet, Commits nicht gepusht,
# neue Commits auf GitHub (noch nicht gepullt).
# Die Abfrage bei GitHub ist `git ls-remote` ueber HTTPS (kein SSH-Agent, kein
# 1Password-Dialog, nichts im Repo wird veraendert) mit hartem Timeout.
# macOS-kompatibel (bash 3.2).

REPO="${MAC_SETUP_REPO:-$HOME/mac-setup}"
CACHE_DIR="$HOME/.cache/mac-setup"
REMOTE_CACHE="$CACHE_DIR/drift-remote"      # "<sha> <branch>", mtime = letzter Erfolg
ATTEMPT_FILE="$CACHE_DIR/drift-attempt"     # mtime = letzter Versuch
TIMEOUT="${DRIFT_TIMEOUT:-10}"
INTERVAL_MIN="${DRIFT_INTERVAL_MIN:-30}"
MODE="${1:-report}"

git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || exit 0
BRANCH=$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ] || exit 0
mkdir -p "$CACHE_DIR"

run_timeout() {   # run_timeout <sekunden> <befehl...>  (stdout des Befehls bleibt erhalten)
    local secs="$1" pid killer rc
    shift
    "$@" &
    pid=$!
    ( sleep "$secs"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
    killer=$!
    wait "$pid" 2>/dev/null
    rc=$?
    kill "$killer" 2>/dev/null
    wait "$killer" 2>/dev/null
    return $rc
}

remote_https_url() {
    local url
    url=$(git -C "$REPO" remote get-url origin 2>/dev/null) || return 1
    case "$url" in
        git@github.com:*)  echo "https://github.com/${url#git@github.com:}" ;;
        ssh://git@github.com/*) echo "https://github.com/${url#ssh://git@github.com/}" ;;
        *) echo "$url" ;;
    esac
}

refresh_cache() {   # holt den aktuellen Branch-Stand von GitHub; Rueckgabe 0 bei Erfolg
    local url tmp sha
    url=$(remote_https_url) || return 1
    tmp=$(mktemp)
    GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/usr/bin/true \
        run_timeout "$TIMEOUT" git -c credential.helper= ls-remote "$url" "refs/heads/$BRANCH" > "$tmp" 2>/dev/null
    sha=$(awk 'NR==1{print $1}' "$tmp")
    rm -f "$tmp"
    [ -n "$sha" ] || return 1
    echo "$sha $BRANCH" > "$REMOTE_CACHE"
    return 0
}

cached_sha() {      # liefert den gecachten Remote-Stand (nicht aelter als 7 Tage) oder nichts
    [ -f "$REMOTE_CACHE" ] || return 0
    [ -z "$(find "$REMOTE_CACHE" -mtime +7 2>/dev/null)" ] || return 0
    awk -v b="$BRANCH" '$2==b{print $1}' "$REMOTE_CACHE"
}

case "$MODE" in
    --refresh)
        refresh_cache
        exit $?
        ;;
    --prompt)
        # Hintergrund-Aktualisierung anstossen, falls der letzte Versuch lange her ist
        if [ -z "$(find "$ATTEMPT_FILE" -mmin -"$INTERVAL_MIN" 2>/dev/null)" ]; then
            touch "$ATTEMPT_FILE"
            nohup "$0" --refresh >/dev/null 2>&1 &
        fi
        ;;
    report)
        touch "$ATTEMPT_FILE"
        refresh_cache || REFRESH_FAILED=1
        ;;
    *)
        echo "Aufruf: drift.sh [--prompt|--refresh]" >&2
        exit 2
        ;;
esac

# ---------------- Auswertung ----------------
HEAD_SHA=$(git -C "$REPO" rev-parse HEAD 2>/dev/null)
REMOTE_SHA=$(cached_sha)

WARNINGS=""
add_warn() { WARNINGS="${WARNINGS}${1}"$'\n'; }

DIRTY=$(git --no-optional-locks -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
[ "$DIRTY" -gt 0 ] && add_warn "$DIRTY lokale Änderung(en) nicht committet  →  sync.sh, dann git status"

AHEAD=$(git -C "$REPO" rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)
[ "$REMOTE_SHA" = "$HEAD_SHA" ] && AHEAD=0
[ "$AHEAD" -gt 0 ] && add_warn "$AHEAD Commit(s) nicht gepusht  →  git push"

BEHIND=0
if [ -n "$REMOTE_SHA" ] && [ "$REMOTE_SHA" != "$HEAD_SHA" ]; then
    if git -C "$REPO" cat-file -e "$REMOTE_SHA^{commit}" 2>/dev/null; then
        if git -C "$REPO" merge-base --is-ancestor "$REMOTE_SHA" "$HEAD_SHA" 2>/dev/null; then
            BEHIND=0      # GitHub ist hinter uns -> steht schon unter "nicht gepusht"
        else
            BEHIND=$(git -C "$REPO" rev-list --count "HEAD..$REMOTE_SHA" 2>/dev/null || echo 1)
            [ "$BEHIND" -gt 0 ] || BEHIND=1
        fi
    else
        BEHIND=1          # Objekt lokal unbekannt -> es gibt Neues auf GitHub
    fi
fi
if [ "$BEHIND" -gt 1 ]; then
    add_warn "$BEHIND neue Commits auf GitHub  →  git pull"
elif [ "$BEHIND" -eq 1 ]; then
    add_warn "Neue Änderungen auf GitHub  →  git pull"
fi

if [ "$MODE" = "--prompt" ]; then
    [ -n "$WARNINGS" ] || exit 0
    if [ -t 1 ]; then Y=$'\033[33m'; N=$'\033[0m'; else Y=""; N=""; fi
    printf '%s' "$WARNINGS" | while IFS= read -r line; do
        printf '%s⚠ mac-setup: %s%s\n' "$Y" "$line" "$N"
    done
    exit 0
fi

# ---------------- Bericht ----------------
SHORT_HEAD=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)
if [ -n "$REMOTE_SHA" ]; then
    echo "mac-setup ($BRANCH): lokal $SHORT_HEAD, GitHub ${REMOTE_SHA:0:7}"
elif [ -n "$REFRESH_FAILED" ]; then
    echo "mac-setup ($BRANCH): lokal $SHORT_HEAD, GitHub-Stand unbekannt (Abfrage fehlgeschlagen, offline?)"
else
    echo "mac-setup ($BRANCH): lokal $SHORT_HEAD, GitHub-Stand unbekannt"
fi
if [ -z "$WARNINGS" ]; then
    if [ -n "$REMOTE_SHA" ]; then
        echo "✔ keine lokalen Änderungen, nichts zu pushen oder zu pullen"
    else
        echo "✔ keine lokalen Änderungen, nichts zu pushen"
        echo "  (Abgleich mit GitHub nicht möglich - nur lokale Prüfung)"
    fi
    exit 0
fi
printf '%s' "$WARNINGS" | while IFS= read -r line; do echo "⚠ $line"; done
exit 1
