# mac-setup – Hinweise für Claude

Öffentliches Repo (`guidowoller/mac-setup`) zum Einrichten und Pflegen mehrerer Macs.
Sprache: Deutsch. Bei Unsicherheit klar sagen, nichts erfinden (keine Fakten, Quellen, Zahlen).

## Rollen
- Pro Mac eine Rolle in `~/.mac-role`: `privat` oder `uni`.
- `privat`: u. a. ms365-Kalendersync. `uni`: Uni-Infrastruktur (SSH-Aliase, LDAP, WireGuard).
- Rollenabhängiges Verhalten gehört in `setup.sh`, nicht in getrennte Skripte.

## Harte Regeln (Repo ist öffentlich)
- Keine Uni-Hostnamen, IPs, Benutzer, Ports, Domains, Private Keys, Tokens ins Repo,
  auch nicht in Kommentaren, Commit-Messages, Doku oder Tests.
- Solche Werte liegen in 1Password (Item `Mac-Setup Uni` und WG-Items pro Mac) und kommen
  über `templates/*.tpl` mit `op inject` / `op read` in die Zielkonfiguration.
- Installierte Configs (`~/.ssh/config`, WireGuard, LDAP) nie ins Repo zurücksynchronisieren
  (`sync.sh` tut das bewusst nicht).
- Der pre-commit-Hook (`hooks/pre-commit`) prüft gegen `~/.config/mac-setup/forbidden.txt`
  (außerhalb des Repos, aus 1Password abgeleitet). Nicht mit `--no-verify` umgehen.
  Ausnahme im Einzelfall: Zeilenmarker `pre-commit:allow`.
- Niemals `op read`/`op item get`-Ausgaben, Keys oder Tokens in die Unterhaltung ausgeben.
  Public Keys ableiten mit `... | wg pubkey` und nur diese zeigen.
- Keine History-Umschreibungen oder Force-Pushes ohne ausdrückliche Zustimmung.

## Technische Vorgaben
- Skripte laufen unter macOS bash 3.2 (keine assoziativen Arrays, kein `mapfile`, kein `${var,,}`).
- Idempotent schreiben (Re-Runs müssen sicher sein); Symlinks mit `ln -sfn`.
- Exec-Bit bei neuen Skripten setzen (`chmod +x`) und mit `git ls-files -s` auf 100755 prüfen.
- Kein `git add .` blind; Commit über `update.sh` (backup → bestätigen → pull --rebase → push).
- Neue Skripte in `scripts/` werden nach `~/bin` verlinkt (siehe `upgrade.sh`) und in
  `doctor.sh` (BIN_SCRIPTS) aufgeführt.

## Werkzeuge im Repo
- `setup.sh` Ersteinrichtung/Re-Run · `doctor.sh` Gesundheitscheck (inkl. Git-History-Hygiene)
- `scripts/drift.sh` Abweichung Repo ↔ Mac · `scripts/brewcheck.sh` Brewfile-Abgleich
- `scripts/histsync.sh` Shell-History per iCloud · `scripts/upgrade.sh` Pull + Updates
- Dotfiles in `dotfiles/` sind per Symlink verlinkt; `.zshrc.iterm` wird nur in iTerm geladen.

## Vor jedem Commit
`bash -n` auf geänderte Skripte, `./doctor.sh` ausführen, `git status` ansehen.
