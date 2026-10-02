# mac-setup

Personal macOS bootstrap setup.

This repository contains everything required to set up a new Mac quickly and reproducibly:

- Homebrew packages
- shell configuration
- tmux / vim / nvim configuration
- scripts (mode, vpn, ms365)
- SSH configuration
- WireGuard templates (without infrastructure data, see below)
- VS Code settings and extensions
- macOS preference restore
- Apache Directory Studio configuration

---

## 🚀 Bootstrap a new Mac

After a fresh macOS install, sign in to iCloud and run the script from the
iCloud Drive folder `bootstrap`:

    bash ~/Library/Mobile\ Documents/com~apple~CloudDocs/bootstrap/mac-bootstrap.sh

(`get_mac-setup.sh` in the same folder only clones the repo, for manual use.)

This will:

1. Install the Xcode Command Line Tools (if missing; run the script again afterwards)  
2. Clone this repository shallow (`--depth 1`, without history) to `~/mac-setup`, or pull it if it already exists  
3. Run `bootstrap.sh` from the repo: installs Homebrew  
4. Run `setup.sh`: installs all tools and configuration  

The folder `bootstrap` also holds `wallpaper.jpg`, which `setup.sh` uses as a
fallback default wallpaper. The repo itself no longer contains the image.

---

## ⚙️ What setup.sh does

The setup script performs the following tasks:

- installs all Homebrew packages
- applies dotfiles (zsh, git, tmux, etc.)
- installs and links scripts to `~/bin`
- configures 1Password SSH agent
- installs and configures WireGuard
- sets up VS Code, Neovim and iTerm2
- restores macOS preferences
- sets the default wallpaper (`~/Documents/wallpaper/wallpaper-freizeit.jpg`, comes from iCloud Drive; skipped if not synced yet)
- restores Apache Directory Studio (LDAP) configuration
- installs the LaunchAgents from `launchagents/` (depending on the Mac role, see below)

---

## ⚠️ Interactive steps during setup

During execution, manual interaction is required:

### 1Password
- Enable:  
  `1Password → Settings → Developer → Use SSH Agent`
- Press ENTER to continue

### WireGuard
- Choose environment:
  - `u` = university
  - `p` = private

### Eclipse / Apache Directory Studio
- Install plugin:
  - Help → Install New Software  
  - https://directory.apache.org/studio/update/  
  - Install: LDAP Browser
- Press ENTER after completion

---

## 🧠 Available Commands

### Mode (environment control)

    mode arbeit
    mode freizeit
    mode alles
    mode ich
    mode status

Controls:
- macOS Focus mode
- wallpaper
- running applications
- VPN state

---

### VPN (WireGuard)

    vpn start
    vpn stop
    vpn status

---

### MS365 / calendar sync (private Mac only)

    ms365.sh run
    ms365.sh check

`sync_calendars.py` (run via `uv`) mirrors the BDV and DDV calendars into the
iCloud calendar "Guido". `ms365sync-run.sh` wraps it for launchd and writes a
status line for `ms365.sh check`.

### Downloads watcher

`watch_downloads.sh` (fswatch, via launchd) moves finished files from
`~/Downloads` to iCloud Drive/Downloads (`sync_downloads.sh`). Log:
`~/Library/Logs/downloads-sync.log`.

---

## 🏷️ Mac role

`setup.sh` asks once whether this is a university (`u`) or private (`p`) Mac
and stores the answer in `~/.mac-role` (`uni` or `privat`). The role controls:

- which 1Password WireGuard items are used
- which LaunchAgents are installed: the downloads watcher on every Mac, the
  calendar sync (`com.guido.ms365sync`) only on the private Mac, so that only
  one machine writes to the shared iCloud calendar

---

## 🔐 WireGuard, LDAP, SSH alias (data from 1Password)

The repository contains no university infrastructure data (no endpoints,
AllowedIPs, peer keys, LDAP host, SSH host). Only templates with
`{{ op://... }}` references live in `templates/`; `setup.sh` fills them with
`op inject` while 1Password is unlocked:

| Template | Result |
| --- | --- |
| `templates/wg-*.conf.tpl` | `/opt/homebrew/etc/wireguard/wg-*.conf` |
| `templates/ldap-connections.xml.tpl` | Directory Studio `connections.xml` in `~/eclipse-workspace` |
| `templates/ssh-uni.conf.tpl` | `~/.ssh/config.d/uni.conf` (alias `uni`) |

Shared item for both Macs: Secure Note `Mac-Setup Uni` in vault `University`,
section `uni`, fields (type Text): `wg_fim5_peer_public_key`,
`wg_fim5_endpoint`, `wg_fim5_allowed_ips`, `wg_faith_peer_public_key`,
`wg_faith_endpoint`, `wg_faith_allowed_ips`, `ldap_host`, `ldap_port`,
`ldap_bind_dn`, `uni_ssh_host`, `uni_ssh_user`.

Per-Mac items (role `uni` / `privat`) with the fields `private` and `address`:
`WG-FIM5 Neu Guido Mac Uni|Privat` and `WG-FAITH Neu Guido Mac Uni|Privat`.
Each of these fields must exist exactly once; otherwise setup skips the config
and reports why.

If 1Password is locked or a field is missing, setup does not abort: it skips
the affected file, lists the reason at the end, and `doctor.sh` reports
missing or unfilled files. Rerun `./setup.sh` afterwards.

---

## 🛡️ Pre-commit hook (no infrastructure data in the repo)

`hooks/pre-commit` runs before every commit and checks only the lines you add:

- against a list of forbidden terms (hostnames, IPs, peer keys, bind DN, ...)
  in `~/.config/mac-setup/forbidden.txt` - **outside** the repo, generated from
  the 1Password item `Mac-Setup Uni` by `hooks/update-forbidden.sh`
  (`setup.sh` runs it and sets `core.hooksPath` to `hooks`)
- against generic patterns (WireGuard `PrivateKey` with a real key, PEM private
  keys, 1Password service tokens)

Extra terms can be added by hand, one per line, in
`~/.config/mac-setup/forbidden-extra.txt`. Mark a line deliberately with
`pre-commit:allow` to skip it; bypass everything with `git commit --no-verify`
(not recommended). `doctor.sh` checks the setup and runs a self-test.

---

## 📡 Drift display

With several Macs, `mac-setup` easily drifts apart. `scripts/drift.sh`
(installed as `~/bin/drift.sh`, alias `drift`) shows whether this Mac differs
from GitHub: uncommitted local changes, commits not pushed, new commits not
pulled yet.

- `drift` - full report with a fresh query (exit code 1 on drift)
- iTerm shells run `drift.sh --prompt` at startup (from `dotfiles/.zshrc.iterm`):
  quiet unless there is something to do; the GitHub query (`git ls-remote` over
  HTTPS, hard timeout, no SSH agent / 1Password prompt) runs in the background at
  most every 30 minutes, so a warning about news on GitHub appears in the next
  shell after the query finished
- `doctor.sh` includes the same check as a warning

It only displays; it never pulls or pushes by itself.

---

## 🍺 Brewfile check

`scripts/brewcheck.sh` (installed as `~/bin/brewcheck.sh`, alias `brewcheck`)
compares this Mac with the `Brewfile`:

- in the Brewfile but not installed here (`brew bundle check`)
- installed here but not in the Brewfile (`brew bundle cleanup`, dry run only;
  aliases and dependencies are handled by brew itself)

`brewcheck --add` offers each unlisted package interactively for the Brewfile
(`y`/`N`/`q`); it never uninstalls anything. Packages that should deliberately
exist on one Mac only go into `~/.config/mac-setup/brew-ignore.txt` (one name
per line, not part of the repo). `doctor.sh` shows the result as a warning.

---

## 📜 Shell history sync (iCloud)

The zsh history is shared between the Macs through iCloud Drive without a
shared file that two Macs write to (which causes conflict copies and lost
lines):

- each Mac publishes only its **own** file:
  `iCloud Drive/shell-history/<computer name>.zsh_history`
- when an iTerm shell starts, `scripts/histsync.sh start` merges the files of the
  other Macs into the local `~/.zsh_history` (deduplicated by timestamp and
  command, sorted by time, at most 50000 entries) and publishes the own file;
  a shell exit publishes it again
- needs `EXTENDED_HISTORY` (set in `dotfiles/.zshrc.iterm`). Before the first merge
  `~/.zsh_history.pre-histsync` is saved as a backup
- `histsync status` shows files, entry counts and age

Limits: the history lies unencrypted in iCloud. `HISTORY_IGNORE` skips commands
with obvious secrets (`PASSWORD=`, `TOKEN=`, ...), commands starting with a space
are never stored - still, do not type secrets on the command line. Entries from the
other Mac appear in the next new shell after iCloud has delivered the file. Open
shells keep their own session; a merge replaces the history file, so a command
written in the same millisecond by another tab can get lost (very rare).

---

## ⬆️ Upgrade routine (`upgrade`)

Two scripts, two directions:

- `update.sh` (alias `update`) brings **your local configuration into the repo**
  (backup, commit, push)
- `scripts/upgrade.sh` (alias `upgrade`) brings **this Mac up to the repo's state**
  and keeps the software current:
  1. `git pull --ff-only` for mac-setup (skipped if tracked files have local changes)
  2. `brew update`, `brew upgrade`, `brew upgrade --cask`, `brew cleanup -s`
  3. `brew bundle --no-upgrade`: installs packages that other Macs added to the
     Brewfile (upgrades nothing extra)
  4. links new scripts from `scripts/` into `~/bin`
  5. shows pending macOS updates (installing stays manual: `sudo softwareupdate -ia`)

  At the end it lists what worked, what needs attention and hints such as
  "run `./setup.sh` again" when setup-relevant files changed. `upgrade --check`
  only shows drift, Brewfile differences, outdated packages and macOS updates and
  changes nothing. It never runs `setup.sh`, installs macOS updates or uninstalls
  packages by itself.

---

## 🔄 Updating configuration

To sync local changes back into the repository:

    sync.sh

Then commit:

    git add .
    git commit -m "update config"
    git push

---

## 📁 Repository structure

    mac-setup/
    ├── Brewfile
    ├── bootstrap.sh
    ├── setup.sh
    ├── scripts
    ├── dotfiles
    ├── config
    ├── launchagents
    ├── templates
    ├── hooks
    ├── apache-directory-studio
    ├── vscode
    ├── macos
    └── ssh

---

## 📋 Post-Install Checklist

See:

    POST-INSTALL.md

This file is intended as a temporary checklist and can be deleted after setup is complete.
