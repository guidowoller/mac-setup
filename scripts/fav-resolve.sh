#!/bin/bash
# fav-resolve.sh - Logik fuer die Shell-Funktion `fav` (Favoriten-Verzeichnisse)
#
#   fav-resolve.sh list [--menu]     Tabelle: kuerzel<TAB>name<TAB>pfad<TAB>status<TAB>modi
#                                    --menu: nur Eintraege, die im aktuellen Modus (~/.mac-mode) gelten
#   fav-resolve.sh get <abfrage>     Pfad zu Kuerzel/Name/eindeutigem Namensanfang (immer alle Eintraege)
#                                    (Exit 1 = nicht gefunden, 2 = mehrdeutig)
#   fav-resolve.sh names             Zeilen fuer die zsh-Vervollstaendigung
#   fav-resolve.sh add <dir> [-s] <name> [kuerzel]   Eintrag speichern (Standard: favorites-local.txt; -s = favorites.txt)
#   fav-resolve.sh path-local        Pfad der favorites-local.txt (fuer `fav edit`)
#
# Dateien (spaetere ueberschreiben fruehere gleichen Namens), beide ausserhalb des Repos:
#   iCloud: bootstrap/favorites.txt             allgemeine Favoriten
#   iCloud: bootstrap/favorites-local.txt       eigene/persoenliche Favoriten (ueberschreiben die allgemeinen)
# Beide synchronisieren ueber iCloud auf alle Macs; was nur in bestimmten Modi im Menue
# erscheinen soll, wird ueber das 4. Feld (modi) gesteuert.
# Vorlage fuer die iCloud-Datei: config/favorites.example.txt im Repo
#
# Zeilenformat:  kuerzel[/kuerzel...];name[/alias...];pfad[;modi]
#   modi (optional, Komma-getrennt, z. B. arbeit,alles): Eintrag erscheint nur im Menue,
#   wenn der Modus aus ~/.mac-mode dazu passt. Ohne Angabe: immer. Direktes `f <kuerzel>`
#   funktioniert unabhaengig vom Modus. Fehlt ~/.mac-mode, werden alle Eintraege gezeigt.
# Kompatibel mit bash 3.2 (macOS).

REPO="${MAC_SETUP_REPO:-$HOME/mac-setup}"
SHARED="${FAV_SHARED:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/bootstrap/favorites.txt}"
LOCAL="${FAV_LOCAL:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/bootstrap/favorites-local.txt}"
MODE_FILE="${FAV_MODE_FILE:-$HOME/.mac-mode}"

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Umgebende Anfuehrungszeichen und Leerraum entfernen
strip() {
    local v="$1"
    v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
    case "$v" in
        \'*\') v="${v#\'}"; v="${v%\'}" ;;
        \"*\") v="${v#\"}"; v="${v%\"}" ;;
    esac
    printf '%s' "$v"
}

# Pfad aufloesen: Escapes entfernen, ~ und $HOME ersetzen, Glob (* ?) -> erster Treffer
resolve_path() {
    local p="$1" m
    local IFS=$'\n'
    p="${p//\\/}"
    case "$p" in
        "~"|"~/"*) p="$HOME${p#\~}" ;;
    esac
    p="${p//\$HOME/$HOME}"
    set +f
    for m in $p; do
        if [ -e "$m" ]; then
            printf '%s' "$m"
            return
        fi
    done
    printf '%s' "$p"
}

# Alle Eintraege: kuerzel<TAB>name<TAB>pfad<TAB>modi  (Kleinschreibung; gleicher Name: letzter gewinnt)
table() {
    local f line keys name path modes
    for f in "$SHARED" "$LOCAL"; do
        [ -f "$f" ] || continue
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in ''|'#'*) continue ;; esac
            IFS=';' read -r keys name path modes <<EOL
$line
EOL
            path="$(strip "$path")"
            [ -n "$name" ] && [ -n "$path" ] || continue
            printf '%s\t%s\t%s\t%s\n' "$(lower "$(strip "$keys")")" "$(lower "$(strip "$name")")" \
                "$(resolve_path "$path")" "$(lower "$(strip "$modes")")"
        done < "$f"
    done | awk -F'\t' '{ if (!($2 in pos)) { pos[$2]=++n; order[n]=$2 } row[$2]=$0 }
                       END { for (i=1;i<=n;i++) print row[order[i]] }'
}

current_mode() {
    [ -f "$MODE_FILE" ] && lower "$(strip "$(cat "$MODE_FILE" 2>/dev/null)")"
}

# Gilt der Eintrag (modi) im aktuellen Modus?
mode_ok() {
    local modes="$1" cur
    [ -z "$modes" ] && return 0
    cur="$(current_mode)"
    [ -z "$cur" ] && return 0
    case ",$modes," in *",$cur,"*) return 0 ;; esac
    return 1
}

if [ ! -f "$SHARED" ] && [ -t 2 ]; then
    echo "Hinweis: gemeinsame Favoritenliste fehlt: $SHARED" >&2
    echo "         Vorlage: $REPO/config/favorites.example.txt" >&2
fi

cmd="$1"
case "$cmd" in
    list)
        tab="$(table)"
        # Doppelt belegte Kuerzel melden (nur im Terminal)
        if [ -t 2 ]; then
            printf '%s\n' "$tab" | awk -F'\t' '{ n=split($1,k,"/"); for(i=1;i<=n;i++) if(k[i]!="") { if(k[i] in o && o[k[i]]!=$2) print "Warnung: Kuerzel \"" k[i] "\" doppelt: " o[k[i]] " und " $2 > "/dev/stderr"; o[k[i]]=$2 } }'
        fi
        while IFS=$'\t' read -r keys name path modes; do
            [ -n "$name" ] || continue
            if [ "$2" = "--menu" ] && ! mode_ok "$modes"; then continue; fi
            st=""
            [ -d "$path" ] || st="(fehlt)"
            printf '%s\t%s\t%s\t%s\t%s\n' "$keys" "$name" "$path" "$st" "$modes"
        done <<EOT
$tab
EOT
        ;;
    path-local)
        printf '%s\n' "$LOCAL"
        ;;
    names)
        table | while IFS=$'\t' read -r keys name path modes; do
            esc="${path//:/\\:}"
            old="$IFS"; IFS='/'
            for n in $name; do printf '%s:%s\n' "$n" "$esc"; done
            for k in $keys; do printf '%s:%s\n' "$k" "${name%%/*}"; done
            IFS="$old"
        done
        ;;
    get)
        q="$(lower "$(strip "$2")")"
        [ -n "$q" ] || exit 1
        tab="$(table)"
        # 1) exaktes Kuerzel, 2) exakter Name/Alias (spaetere Eintraege zuerst, damit lokal gewinnt)
        rev="$(printf '%s\n' "$tab" | awk '{ l[NR]=$0 } END { for (i=NR;i>=1;i--) print l[i] }')"
        while IFS=$'\t' read -r keys name path modes; do
            old="$IFS"; IFS='/'
            for k in $keys; do
                if [ "$k" = "$q" ]; then IFS="$old"; printf '%s\n' "$path"; exit 0; fi
            done
            IFS="$old"
        done <<EOT
$rev
EOT
        while IFS=$'\t' read -r keys name path modes; do
            old="$IFS"; IFS='/'
            for n in $name; do
                if [ "$n" = "$q" ]; then IFS="$old"; printf '%s\n' "$path"; exit 0; fi
            done
            IFS="$old"
        done <<EOT
$rev
EOT
        # 3) eindeutiger Namensanfang
        hits=0; hitpath=""; hitnames=""
        while IFS=$'\t' read -r keys name path modes; do
            old="$IFS"; IFS='/'
            for n in $name; do
                case "$n" in
                    "$q"*) hits=$((hits+1)); hitpath="$path"; hitnames="$hitnames $n"; break ;;
                esac
            done
            IFS="$old"
        done <<EOT
$tab
EOT
        if [ "$hits" -eq 1 ]; then printf '%s\n' "$hitpath"; exit 0; fi
        if [ "$hits" -gt 1 ]; then echo "mehrdeutig:$hitnames" >&2; exit 2; fi
        exit 1
        ;;
    add)
        dir="$2"; target="$LOCAL"
        if [ "$3" = "-s" ]; then target="$SHARED"; set -- "$1" "$2" "${@:4}"; fi
        name="$(lower "$3")"; keys="$(lower "$4")"
        if [ -z "$dir" ] || [ -z "$name" ]; then
            echo "Usage: fav add [-s] <name> [kuerzel]" >&2; exit 2
        fi
        case "$name" in
            *[!a-z0-9_-]*) echo "Name nur a-z, 0-9, _ und -" >&2; exit 2 ;;
        esac
        case "$keys" in
            *';'*|*' '*) echo "Kuerzel: mehrere mit / trennen (z. B. o/1)" >&2; exit 2 ;;
        esac
        mkdir -p "$(dirname "$target")" || exit 1
        if [ -f "$target" ] && cut -d';' -f2 "$target" | tr '[:upper:]' '[:lower:]' | grep -qx "$name"; then
            echo "Favorit '$name' existiert bereits in $target (fav edit)" >&2; exit 1
        fi
        shown="$dir"
        case "$dir" in "$HOME"|"$HOME"/*) shown="~${dir#$HOME}" ;; esac
        printf '%s;%s;%s\n' "$keys" "$name" "$shown" >> "$target"
        echo "✓ Favorit '$name' -> $shown  ($target)"
        ;;
    *)
        echo "Usage: $(basename "$0") list [--menu]|get <abfrage>|names|path-local|add <dir> [-s] <name> [kuerzel]" >&2
        exit 2
        ;;
esac
