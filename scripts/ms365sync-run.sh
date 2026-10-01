#!/bin/bash
#
# ms365sync-run.sh
#
# Startet sync_calendars.py (uv) und schreibt am Ende eine Statuszeile im Format
#   <ISO-Zeitstempel> ms365sync: OK|FAIL ...
# damit "ms365.sh check" den letzten Lauf weiterhin erkennen kann.
# Wird stuendlich von launchd aufgerufen (Label com.guido.ms365sync).

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

HERE="$(cd "$(dirname "$0")" && pwd)"
PY_SCRIPT="$HERE/sync_calendars.py"
LOG="$HOME/Library/Logs/ms365sync.out.log"
LOCKDIR="${TMPDIR:-/tmp}/com.guido.ms365sync.lock"

stamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }

# Log nicht endlos wachsen lassen (letzte 2000 Zeilen behalten)
if [[ -f "$LOG" ]] && (( $(wc -l < "$LOG") > 4000 )); then
  tail -n 2000 "$LOG" > "$LOG.tmp" && cat "$LOG.tmp" > "$LOG" && rm -f "$LOG.tmp"
fi

# Nicht zwei Laeufe gleichzeitig
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "$(stamp) ms365sync: SKIP (laeuft bereits)"
  exit 0
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

UV_BIN="$(command -v uv)"
if [[ -z "$UV_BIN" ]]; then
  echo "$(stamp) ms365sync: FAIL (uv nicht gefunden - brew install uv)"
  exit 1
fi
if [[ ! -f "$PY_SCRIPT" ]]; then
  echo "$(stamp) ms365sync: FAIL (Skript fehlt: $PY_SCRIPT)"
  exit 1
fi

OUT="$("$UV_BIN" run --script "$PY_SCRIPT" 2>&1)"
RC=$?

echo "$OUT"

SUMMARY="$(printf '%s\n' "$OUT" | grep -E '^Zusammenfassung:|^Kein Kalenderzugriff|^Ziel-Kalender|^Fehler' | tail -n 1)"

if (( RC == 0 )); then
  echo "$(stamp) ms365sync: OK ${SUMMARY}"
else
  echo "$(stamp) ms365sync: FAIL (rc=$RC) ${SUMMARY}"
fi
exit $RC
