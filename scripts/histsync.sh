#!/bin/bash
#
# histsync.sh - zsh-History zwischen Macs ueber iCloud Drive abgleichen
#
# Prinzip: jeder Mac schreibt NUR in seine eigene Datei
#   iCloud Drive/shell-history/<Rechnername>.zsh_history
# (keine gemeinsam beschriebene Datei -> keine iCloud-Konflikte). Beim Start einer
# Shell werden die Dateien der anderen Macs in die lokale ~/.zsh_history gemischt
# (dedupliziert nach Zeitstempel + Befehl, nach Zeit sortiert).
#
#   histsync.sh start    Shell-Start: fremde Dateien mergen (nur wenn neu), eigene veroeffentlichen
#   histsync.sh push     eigene History nach iCloud kopieren (Shell-Ende)
#   histsync.sh pull     fremde Dateien in die lokale History mergen
#   histsync.sh status   Dateien, Eintraege, Alter
#
# Voraussetzung: setopt EXTENDED_HISTORY (Zeitstempel). Die History liegt in iCloud
# unverschluesselt bei Apple - Befehle mit offensichtlichen Geheimnissen filtert
# HISTORY_IGNORE in dotfiles/.zshrc.iterm (nur eine Vorsichtsmassnahme).
# macOS-kompatibel (bash 3.2, System-python3).

HOST="${HISTSYNC_HOST:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
LOCAL="${HISTSYNC_LOCAL:-$HOME/.zsh_history}"
DIR="${HISTSYNC_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/shell-history}"
MAX_ENTRIES="${HISTSYNC_MAX:-50000}"
STAMP_DIR="$HOME/.cache/mac-setup"
STAMP="$STAMP_DIR/histsync-stamp"
OWN="$DIR/$HOST.zsh_history"
MODE="${1:-start}"

mkdir -p "$DIR" "$STAMP_DIR" 2>/dev/null

# Datei in iCloud nur lesen, wenn sie lokal vorhanden ist; sonst Download anstossen
usable() {
    local f="$1" ph
    ph="$(dirname "$f")/.$(basename "$f").icloud"
    if [ -e "$ph" ]; then
        command -v brctl >/dev/null 2>&1 && brctl download "$f" >/dev/null 2>&1 &
        return 1
    fi
    [ -f "$f" ] || return 1
    case "$(ls -lO "$f" 2>/dev/null)" in
        *dataless*) command -v brctl >/dev/null 2>&1 && brctl download "$f" >/dev/null 2>&1 &
                    return 1 ;;
    esac
    return 0
}

others() {   # fremde History-Dateien (auch nur als iCloud-Platzhalter vorhanden)
    local f
    for f in "$DIR"/*.zsh_history; do
        [ -e "$f" ] || continue
        [ "$f" = "$OWN" ] && continue
        echo "$f"
    done
    for f in "$DIR"/.*.zsh_history.icloud; do
        [ -e "$f" ] || continue
        f="${f%.icloud}"; f="$(dirname "$f")/$(basename "$f" | sed 's/^\.//')"
        [ "$f" = "$OWN" ] && continue
        echo "$f"
    done
}

do_push() {
    [ -f "$LOCAL" ] || return 0
    cmp -s "$LOCAL" "$OWN" 2>/dev/null && return 0
    cp "$LOCAL" "$DIR/.$HOST.tmp" 2>/dev/null && mv "$DIR/.$HOST.tmp" "$OWN"
}

do_pull() {
    local files=() f
    while IFS= read -r f; do
        usable "$f" && files+=("$f")
    done < <(others)
    if [ "${#files[@]}" -eq 0 ]; then touch "$STAMP"; return 0; fi
    [ -f "$LOCAL" ] || : > "$LOCAL"
    [ -f "$LOCAL.pre-histsync" ] || cp "$LOCAL" "$LOCAL.pre-histsync"
    python3 - "$LOCAL" "$MAX_ENTRIES" "${files[@]}" <<'PY'
import os, re, sys

local, max_entries, others = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
head = re.compile(rb'^: (\d+):(\d+);')

def parse(path):
    """Eintraege als (zeitstempel, rohtext); Fortsetzungszeilen (Backslash am Ende) gehoeren dazu."""
    with open(path, 'rb') as fh:
        data = fh.read()
    entries, cur = [], None
    for line in data.split(b'\n'):
        m = head.match(line)
        if m:
            cur = [int(m.group(1)), [line]]
            entries.append(cur)
        elif cur is not None and (len(cur[1][-1]) - len(cur[1][-1].rstrip(b'\\'))) % 2 == 1:
            cur[1].append(line)
        elif line.strip() == b'':
            cur = None
        else:                                   # Zeile ohne Zeitstempel (altes Format)
            cur = [0, [line]]
            entries.append(cur)
    return [(ts, b'\n'.join(lines)) for ts, lines in entries]

merged, seen = [], set()
for path in [local] + others:
    try:
        entries = parse(path)
    except OSError:
        continue
    for ts, raw in entries:
        if raw in seen:
            continue
        seen.add(raw)
        merged.append((ts, raw))

merged.sort(key=lambda e: e[0])                  # stabil: gleiche Zeit behaelt Reihenfolge
merged = merged[-max_entries:]
out = b'\n'.join(raw for _, raw in merged) + b'\n'

with open(local, 'rb') as fh:
    old = fh.read()
if out != old:
    tmp = local + '.histsync.tmp'
    with open(tmp, 'wb') as fh:
        fh.write(out)
    os.replace(tmp, local)
PY
    local rc=$?
    [ "$rc" -eq 0 ] && touch "$STAMP"
    return $rc
}

count_entries() { grep -c -E '^: [0-9]+:[0-9]+;' "$1" 2>/dev/null || echo 0; }

case "$MODE" in
    start)
        need=0
        while IFS= read -r f; do
            if [ ! -f "$STAMP" ] || [ "$f" -nt "$STAMP" ] || [ ! -f "$f" ]; then need=1; fi
        done < <(others)
        [ "$need" -eq 1 ] && do_pull
        do_push
        ;;
    push)   do_push ;;
    pull)   do_pull ;;
    status)
        echo "Rechner:   $HOST"
        echo "Lokal:     $LOCAL ($(count_entries "$LOCAL") Einträge)"
        echo "iCloud:    $DIR"
        for f in "$DIR"/*.zsh_history; do
            [ -e "$f" ] || continue
            printf '  %-40s %6s Einträge  %s%s\n' "$(basename "$f")" "$(count_entries "$f")" \
                "$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)" "$([ "$f" = "$OWN" ] && echo '  (dieser Mac)')"
        done
        others | while IFS= read -r f; do usable "$f" || echo "  $(basename "$f"): noch nicht heruntergeladen (iCloud)"; done
        ;;
    *)  echo "Aufruf: histsync.sh [start|push|pull|status]" >&2; exit 2 ;;
esac
