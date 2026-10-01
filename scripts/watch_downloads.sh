#!/bin/bash
#
# watch_downloads.sh - laeuft dauerhaft (launchd KeepAlive), ruft sync_downloads.sh bei Aenderungen auf.

SYNC_SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync_downloads.sh"   # Schwesterdatei (auch via Symlink in ~/bin)
SRC="$HOME/Downloads"
LOG="$HOME/Library/Logs/downloads-sync.log"

# launchd hat kein Homebrew im PATH -> explizit suchen
FSWATCH_BIN=""
for c in /opt/homebrew/bin/fswatch /usr/local/bin/fswatch; do [[ -x "$c" ]] && FSWATCH_BIN="$c" && break; done
if [[ -z "$FSWATCH_BIN" ]]; then
  echo "$(date '+%FT%T%z') FEHLER: fswatch nicht gefunden (brew install fswatch)" >> "$LOG"
  sleep 60; exit 1     # sleep verhindert KeepAlive-Endlosschleife im Sekundentakt
fi

run_sync() {
  "$SYNC_SCRIPT"; local rc=$? tries=0
  # Bei "zu jungen" Dateien (rc 10) erneut versuchen, weil danach evtl. kein Event mehr kommt
  while (( rc == 10 && tries < 24 )); do sleep 5; "$SYNC_SCRIPT"; rc=$?; tries=$((tries+1)); done
}

run_sync   # einmal beim Start

"$FSWATCH_BIN" -o --latency 1 "$SRC" | while read -r _; do run_sync; done
