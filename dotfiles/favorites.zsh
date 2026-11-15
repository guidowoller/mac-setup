# Favoriten-Verzeichnisse: `fav` (Alias `f`)
#   f            Menue (fzf) mit Vorschau, Enter wechselt dorthin
#   f p          Kuerzel oder Name (nicht case-sensitiv), Namensanfang reicht: f proj
#   f list       Tabelle aller Favoriten
#   f add [-s] <name> [kuerzel]   aktuellen Ordner speichern (favorites-local.txt; -s = favorites.txt)
#   f edit       lokale Favoritenliste bearbeiten
# Liste: iCloud bootstrap/favorites.txt + bootstrap/favorites-local.txt (beide nicht im Repo)
#   Vorlage: config/favorites.example.txt
# Logik: ~/bin/fav-resolve.sh (aus scripts/). Muss eine Funktion sein, damit `cd` die Shell betrifft.

FAV_BIN="${FAV_BIN:-$HOME/bin/fav-resolve.sh}"

fav() {
  local bin="$FAV_BIN" target sel rc

  if [[ ! -x "$bin" ]]; then
    print -u2 "fav: $bin fehlt (./setup.sh oder 'upgrade' ausfuehren)"
    return 1
  fi

  case "$1" in
    -h|--help|help)
      print "fav / f: Verzeichnisse per Kuerzel oder Menue wechseln
  f                 Menue (fzf)
  f <kuerzel|name>  direkt wechseln (z. B. f p, f proj)
  f list            alle Favoriten
  f add [-s] <name> [k]  aktuellen Ordner speichern (-s: allgemeine Liste)
  f edit            eigene Liste bearbeiten"
      return 0 ;;
    list|ls)
      "$bin" list | column -t -s $'\t'
      return 0 ;;
    add)
      shift
      "$bin" add "$PWD" "$@"
      return $? ;;
    edit)
      ${EDITOR:-nvim} "$("$bin" path-local)"
      return $? ;;
  esac

  if [[ -z "$1" ]]; then
    if (( $+commands[fzf] )); then
      sel=$("$bin" list --menu | fzf --delimiter=$'\t' --with-nth=1,2,3,4 --height=60% --reverse \
            --header='Enter = wechseln · Esc = abbrechen' \
            --preview='eza -la --color=always {3} 2>/dev/null || ls -la {3}' \
            --preview-window=right:50%) || return 0
      target=${${(ps:\t:)sel}[3]}
    else
      "$bin" list | column -t -s $'\t'
      return 0
    fi
  else
    target=$("$bin" get "$*")
    rc=$?
    if (( rc == 2 )); then
      return 1
    elif (( rc != 0 )); then
      print -u2 "fav: '$*' nicht gefunden. Vorhandene Favoriten:"
      "$bin" list | column -t -s $'\t' >&2
      return 1
    fi
  fi

  [[ -n "$target" ]] || return 0
  if [[ ! -d "$target" ]]; then
    print -u2 "fav: Ordner fehlt: $target (Cloud nicht synchronisiert/gemountet?)"
    return 1
  fi
  builtin cd -- "$target"
}

# Tab-Vervollstaendigung (Namen + Kuerzel)
_fav() {
  local -a items
  if (( CURRENT == 2 )); then
    items=(${(f)"$("$FAV_BIN" names 2>/dev/null)"} list:'alle anzeigen' add:'aktuellen Ordner speichern (-s: allgemeine Liste)' edit:'eigene Liste bearbeiten' help:'Hilfe')
    _describe -t favs 'Favorit' items
  fi
}
(( $+functions[compdef] )) && compdef _fav fav f

alias f=fav
