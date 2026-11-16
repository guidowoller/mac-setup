#!/bin/bash
#
# repos-sync.sh - Git-Repos aus einer Liste nach ~/git klonen und aktuell halten
#
#   repos-sync.sh           fehlende Repos klonen, saubere Repos per --ff-only pullen,
#                           Doku-Repos (typ mkdocs) mit VS-Code-Workspace-Vorlage versehen
#   repos-sync.sh --check   nur Status anzeigen, nichts veraendern
#
# Die Liste liegt NICHT im Repo (URLs koennen Uni-Infrastruktur verraten), sondern in
#   iCloud Drive/bootstrap/repos.txt        Vorlage: config/repos.example.txt
# Zeilenformat: name|url|typ   (typ optional, z. B. mkdocs; Kommentare mit #)
#
# Sicher fuer Re-Runs: kein Force, kein Reset, Repos mit lokalen Aenderungen werden
# uebersprungen. Erreichbarkeitsfehler (z. B. Uni-GitLab ohne VPN) sind Warnungen.
# macOS-kompatibel (bash 3.2).

REPO="${MAC_SETUP_REPO:-$HOME/mac-setup}"
LIST="${REPOS_LIST:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/bootstrap/repos.txt}"
BASE="${REPOS_DIR:-$HOME/git}"
TPL_DIR="$REPO/vscode/workspace"
MODE="${1:-run}"
case "$MODE" in run|--check) ;; *) echo "Aufruf: repos-sync.sh [--check]" >&2; exit 2 ;; esac

if [ ! -f "$LIST" ]; then
    echo "Repo-Liste fehlt: $LIST" >&2
    echo "iCloud noch nicht synchronisiert? Sonst Vorlage kopieren: cp \"$REPO/config/repos.example.txt\" \"$LIST\"" >&2
    exit 1
fi

# Nie nach Passwoertern fragen, nicht haengen bleiben
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes -o ConnectTimeout=10"

N_OK=0; N_WARN=0; N_FAIL=0
ok()   { echo "✔ $1"; N_OK=$((N_OK+1)); }
warn() { echo "⚠ $1"; N_WARN=$((N_WARN+1)); }
fail() { echo "✖ $1"; N_FAIL=$((N_FAIL+1)); }

# Workspace-Vorlage (GitDoc, Bilder einfuegen, Vorschau-Task) nach <repo>/.vscode legen.
# Nur lokal: .vscode/ landet in .git/info/exclude, das Team-Repo bleibt unberuehrt.
# Ist .vscode/settings.json im Repo selbst getrackt, wird nichts ueberschrieben.
apply_mkdocs() {
    local dir="$1" name="$2" changed=0
    if git -C "$dir" ls-files --error-unmatch .vscode/settings.json >/dev/null 2>&1; then
        warn "$name: .vscode/settings.json ist im Repo getrackt - Vorlage nicht angewendet"
        return 0
    fi
    [ -f "$TPL_DIR/mkdocs.settings.json" ] && [ -f "$TPL_DIR/mkdocs.tasks.json" ] || { warn "$name: Vorlagen in $TPL_DIR fehlen"; return 0; }
    if [ "$MODE" = "--check" ]; then
        if cmp -s "$TPL_DIR/mkdocs.settings.json" "$dir/.vscode/settings.json" 2>/dev/null \
           && cmp -s "$TPL_DIR/mkdocs.tasks.json" "$dir/.vscode/tasks.json" 2>/dev/null; then
            ok "$name: VS-Code-Workspace-Vorlage aktuell"
        else
            warn "$name: VS-Code-Workspace-Vorlage fehlt oder weicht ab (repos-sync.sh ohne --check anwenden)"
        fi
        return 0
    fi
    mkdir -p "$dir/.vscode"
    cmp -s "$TPL_DIR/mkdocs.settings.json" "$dir/.vscode/settings.json" 2>/dev/null || { cp "$TPL_DIR/mkdocs.settings.json" "$dir/.vscode/settings.json"; changed=1; }
    cmp -s "$TPL_DIR/mkdocs.tasks.json" "$dir/.vscode/tasks.json" 2>/dev/null || { cp "$TPL_DIR/mkdocs.tasks.json" "$dir/.vscode/tasks.json"; changed=1; }
    local excl="$dir/.git/info/exclude"
    mkdir -p "$dir/.git/info"
    grep -qxF '.vscode/' "$excl" 2>/dev/null || echo '.vscode/' >> "$excl"
    if [ "$changed" -eq 1 ]; then ok "$name: VS-Code-Workspace-Vorlage angewendet"; else ok "$name: VS-Code-Workspace-Vorlage aktuell"; fi
}

[ "$MODE" = "run" ] && mkdir -p "$BASE"

while IFS='|' read -r name url typ || [ -n "$name" ]; do
    name=$(echo "$name" | tr -d '[:space:]')
    url=$(echo "$url" | tr -d '[:space:]')
    typ=$(echo "$typ" | tr -d '[:space:]')
    case "$name" in ""|\#*) continue ;; esac
    case "$name" in */*|.*) fail "$name: ungueltiger Name (kein / oder fuehrender Punkt)"; continue ;; esac
    if [ -z "$url" ]; then fail "$name: URL fehlt"; continue; fi
    dir="$BASE/$name"

    if [ ! -d "$dir/.git" ]; then
        if [ -e "$dir" ]; then fail "$name: $dir existiert, ist aber kein Git-Repo"; continue; fi
        if [ "$MODE" = "--check" ]; then warn "$name: nicht geklont"; continue; fi
        if git clone --quiet "$url" "$dir" 2>/dev/null; then
            ok "$name: geklont"
        else
            warn "$name: Klonen fehlgeschlagen (VPN/SSH-Zugang? URL pruefen)"
            continue
        fi
    else
        if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
            warn "$name: lokale Aenderungen - uebersprungen"
        elif [ "$MODE" = "--check" ]; then
            ok "$name: vorhanden"
        elif git -C "$dir" pull --ff-only --quiet 2>/dev/null; then
            ok "$name: aktuell"
        else
            warn "$name: Pull (ff-only) fehlgeschlagen - Netz/VPN oder abweichende Historie, manuell pruefen"
        fi
    fi

    [ "$typ" = "mkdocs" ] && apply_mkdocs "$dir" "$name"
done < "$LIST"

echo ""
echo "Repos: $N_OK ok, $N_WARN Warnungen, $N_FAIL Fehler"
[ "$N_FAIL" -eq 0 ]
