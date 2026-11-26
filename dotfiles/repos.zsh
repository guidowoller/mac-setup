# Repo-Menue: `repo` (Alias `c`) oeffnet ein Repo aus ~/git in VS Code - ohne das Verzeichnis zu wechseln
#   c            Menue (fzf, Maus geht) mit Vorschau der geklonten Repos, Enter oeffnet in VS Code
#   c <name>     direkt oeffnen (nicht case-sensitiv, Namensanfang reicht: c do)
#   c list       Tabelle der geklonten Repos
# Liste: iCloud bootstrap/repos.txt (nicht im Repo), Vorlage: config/repos.example.txt
# Geklont wird mit scripts/repos-sync.sh. Gezeigt werden nur Repos, die unter ~/git wirklich existieren.

REPOS_LIST_FILE="${REPOS_LIST:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/bootstrap/repos.txt}"
REPOS_BASE_DIR="${REPOS_DIR:-$HOME/git}"

_repos_code_bin() {
  if [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    print -r -- "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  elif (( $+commands[code] )); then
    print -r -- code
  else
    return 1
  fi
}

# Ausgabe je geklontem Repo: name<TAB>pfad<TAB>typ
_repos_entries() {
  local line name typ
  local -a f
  [[ -f "$REPOS_LIST_FILE" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]] && continue
    f=("${(@s:|:)line}")
    name=${f[1]//[[:space:]]/}
    typ=${f[3]//[[:space:]]/}
    [[ -n "$name" && "$name" != */* && "$name" != .* ]] || continue
    [[ -d "$REPOS_BASE_DIR/$name/.git" ]] || continue
    print -r -- "$name"$'\t'"$REPOS_BASE_DIR/$name"$'\t'"$typ"
  done < "$REPOS_LIST_FILE"
}

repo() {
  local entries code_bin sel target l n want
  local -a hits

  case "$1" in
    -h|--help|help)
      print "repo / c: Repo aus ~/git in VS Code oeffnen (ohne cd)
  c            Menue (fzf)
  c <name>     direkt oeffnen (Namensanfang reicht)
  c list       geklonte Repos anzeigen
Neue Repos: Zeile in iCloud bootstrap/repos.txt eintragen, dann repos-sync.sh" ; return 0 ;;
  esac

  if [[ ! -f "$REPOS_LIST_FILE" ]]; then
    print -u2 "c: Repo-Liste fehlt: $REPOS_LIST_FILE (iCloud noch nicht synchronisiert? Vorlage: config/repos.example.txt)"
    return 1
  fi
  entries=$(_repos_entries)
  if [[ -z "$entries" ]]; then
    print -u2 "c: keine geklonten Repos unter $REPOS_BASE_DIR gefunden (repos-sync.sh ausfuehren)"
    return 1
  fi

  case "$1" in
    list|ls)
      { print -r -- $'NAME\tPFAD\tTYP'; print -r -- "$entries"; } | column -t -s $'\t'
      return 0 ;;
  esac

  code_bin=$(_repos_code_bin) || { print -u2 "c: VS Code ('code') nicht gefunden"; return 1 }

  if [[ -z "$1" ]]; then
    if (( $+commands[fzf] )); then
      sel=$(print -r -- "$entries" | fzf --delimiter=$'\t' --with-nth=1,3 --height=60% --reverse \
            --header='Enter = in VS Code oeffnen · Esc = abbrechen' \
            --preview='eza -la --color=always {2} 2>/dev/null || ls -la {2}' \
            --preview-window=right:50%) || return 0
      target=${${(ps:\t:)sel}[2]}
    else
      print -r -- "$entries" | column -t -s $'\t'
      return 0
    fi
  else
    want=${(L)1}
    for l in ${(f)entries}; do
      n=${(L)${(ps:\t:)l}[1]}
      if [[ "$n" == "$want" ]]; then hits=("$l"); break; fi
      [[ "$n" == "$want"* ]] && hits+=("$l")
    done
    if (( ${#hits} == 0 )); then
      print -u2 "c: '$1' nicht gefunden. Geklonte Repos:"
      print -r -- "$entries" | cut -f1 >&2
      return 1
    elif (( ${#hits} > 1 )); then
      print -u2 "c: '$1' ist nicht eindeutig:"
      for l in $hits; do print -u2 -r -- "  ${${(ps:\t:)l}[1]}"; done
      return 1
    fi
    target=${${(ps:\t:)hits[1]}[2]}
  fi

  [[ -n "$target" ]] || return 0
  "$code_bin" "$target"
}

# Tab-Vervollstaendigung (Repo-Namen)
_repo() {
  local -a names
  if (( CURRENT == 2 )); then
    names=(${(f)"$(_repos_entries 2>/dev/null | cut -f1)"} list:'geklonte Repos anzeigen' help:'Hilfe')
    _describe -t repos 'Repo' names
  fi
}
(( $+functions[compdef] )) && compdef _repo repo c

alias c=repo

# `g` (Alias fuer repocd): in ein Repo aus ~/git wechseln (cd) - wie `c`, aber ohne VS Code
#   g            Menue (fzf) mit Vorschau, Enter wechselt dorthin
#   g <name>     direkt wechseln (nicht case-sensitiv, Namensanfang reicht)
# Nutzt dieselbe Liste wie `c` (iCloud bootstrap/repos.txt, nur geklonte Repos). Muss eine Funktion sein, damit `cd` die Shell betrifft.
repocd() {
  local entries sel target l n want
  local -a hits

  case "$1" in
    -h|--help|help)
      print "repocd / g: in ein Repo aus ~/git wechseln (cd)
  g            Menue (fzf)
  g <name>     direkt wechseln (Namensanfang reicht)
Repo in VS Code oeffnen: c"
      return 0 ;;
  esac

  if [[ ! -f "$REPOS_LIST_FILE" ]]; then
    print -u2 "g: Repo-Liste fehlt: $REPOS_LIST_FILE (iCloud noch nicht synchronisiert?)"
    return 1
  fi
  entries=$(_repos_entries)
  if [[ -z "$entries" ]]; then
    print -u2 "g: keine geklonten Repos unter $REPOS_BASE_DIR gefunden (repos-sync.sh ausfuehren)"
    return 1
  fi

  if [[ -z "$1" ]]; then
    if (( $+commands[fzf] )); then
      sel=$(print -r -- "$entries" | fzf --delimiter=$'\t' --with-nth=1,3 --height=60% --reverse \
            --header='Enter = wechseln · Esc = abbrechen' \
            --preview='eza -la --color=always {2} 2>/dev/null || ls -la {2}' \
            --preview-window=right:50%) || return 0
      target=${${(ps:\t:)sel}[2]}
    else
      print -r -- "$entries" | column -t -s $'\t'
      return 0
    fi
  else
    want=${(L)1}
    for l in ${(f)entries}; do
      n=${(L)${(ps:\t:)l}[1]}
      if [[ "$n" == "$want" ]]; then hits=("$l"); break; fi
      [[ "$n" == "$want"* ]] && hits+=("$l")
    done
    if (( ${#hits} == 0 )); then
      print -u2 "g: '$1' nicht gefunden. Geklonte Repos:"
      print -r -- "$entries" | cut -f1 >&2
      return 1
    elif (( ${#hits} > 1 )); then
      print -u2 "g: '$1' ist nicht eindeutig:"
      for l in $hits; do print -u2 -r -- "  ${${(ps:\t:)l}[1]}"; done
      return 1
    fi
    target=${${(ps:\t:)hits[1]}[2]}
  fi

  [[ -n "$target" ]] || return 0
  if [[ ! -d "$target" ]]; then
    print -u2 "g: Ordner fehlt: $target"
    return 1
  fi
  builtin cd -- "$target"
}

# Tab-Vervollstaendigung fuer g (gleiche Repo-Namen wie bei c)
_repocd() {
  local -a names
  if (( CURRENT == 2 )); then
    names=(${(f)"$(_repos_entries 2>/dev/null | cut -f1)"} help:'Hilfe')
    _describe -t repos 'Repo' names
  fi
}
(( $+functions[compdef] )) && compdef _repocd repocd g

alias g=repocd
