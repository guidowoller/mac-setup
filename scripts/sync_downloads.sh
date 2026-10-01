#!/bin/bash
#
# sync_downloads.sh
#
# Verschiebt fertige Dateien aus ~/Downloads nach iCloud Drive/Downloads.
# Exit-Codes: 0 = alles erledigt, 10 = es gibt noch "zu junge" Dateien (später nochmal prüfen)

SRC="$HOME/Downloads"
DEST="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads"
LOG="$HOME/Library/Logs/downloads-sync.log"
MIN_AGE=5   # Sekunden: so lange muss eine Datei unverändert sein

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG"; }

if [[ ! -d "$SRC" ]]; then log "FEHLER: $SRC nicht lesbar/vorhanden (Full Disk Access?)"; exit 1; fi
if ! mkdir -p "$DEST" 2>>"$LOG"; then log "FEHLER: iCloud-Ziel nicht erreichbar: $DEST"; exit 1; fi

SKIP_PATTERNS=("*.download" "*.crdownload" "*.part" "*.partial" "*.tmp" "*.opdownload")

shopt -s nullglob   # bewusst OHNE dotglob: .DS_Store, .localized etc. bleiben liegen

pending=0
now=$(date +%s)

for file in "$SRC"/*; do
  [[ -f "$file" ]] || continue          # Unterordner/Bundles (z.B. Safari .download) ignorieren
  base="$(basename "$file")"

  skip=false
  for pattern in "${SKIP_PATTERNS[@]}"; do
    [[ "$base" == $pattern ]] && { skip=true; break; }
  done
  $skip && continue

  # Datei noch im Schreibzugriff? -> später erneut versuchen
  mtime=$(stat -f %m "$file" 2>/dev/null || echo "$now")
  if (( now - mtime < MIN_AGE )) || lsof -- "$file" >/dev/null 2>&1; then
    pending=1
    continue
  fi

  dest_file="$DEST/$base"
  if [[ -e "$dest_file" ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    name="${base%.*}"; ext="${base##*.}"
    if [[ "$name" == "$ext" || -z "$name" ]]; then dest_file="$DEST/${base}-$ts"
    else dest_file="$DEST/${name}-$ts.$ext"; fi
  fi

  if mv -n "$file" "$dest_file" 2>>"$LOG"; then
    log "moved: $base -> $(basename "$dest_file")"
  else
    log "FEHLER beim Verschieben: $base"
  fi
done

(( pending )) && exit 10
exit 0
