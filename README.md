# mac-setup

Personal macOS bootstrap and maintenance for several Macs.

What the repo covers:

- Homebrew packages (`Brewfile`)
- dotfiles (zsh, git, tmux, vim, nano) and configs (Neovim, Starship, iTerm2)
- helper scripts in `scripts/`, linked to `~/bin` (mode, vpn, ms365, drift, ...)
- 1Password SSH agent, SSH alias, WireGuard and LDAP via templates (no infrastructure data, see below)
- VS Code settings and extensions
- macOS preference restore
- Apache Directory Studio configuration
- Claude Code (CLI) including permission rules (`claude/settings.json`)

---

## 🚀 Bootstrap a new Mac

After a fresh macOS install, sign in to iCloud and run the script from the
iCloud Drive folder `bootstrap`:

    bash ~/Library/Mobile\ Documents/com~apple~CloudDocs/bootstrap/mac-bootstrap.sh

(`get_mac-setup.sh` in the same folder only clones the repo, for manual use.)

This will:

1. install the Xcode Command Line Tools (if missing; run the script again afterwards)
2. clone this repository shallow (`--depth 1`) to `~/mac-setup`, or pull it if it already exists
3. run `bootstrap.sh` from the repo: installs Homebrew
4. run `setup.sh`: installs all tools and configuration

The folder `bootstrap` also holds `wallpaper.jpg`, which `setup.sh` uses as a
fallback default wallpaper (the repo contains no image).

Afterwards work through [`POST-INSTALL.md`](POST-INSTALL.md).

---

## ⚙️ What setup.sh does

`setup.sh` is idempotent and can be rerun at any time. It

- asks for the Mac role once (see below)
- installs all Homebrew packages
- links the dotfiles and scripts (`~/bin`)
- configures the 1Password SSH agent
- fills the templates from 1Password (WireGuard, LDAP, SSH alias)
- sets up VS Code, Neovim and iTerm2
- restores macOS preferences and the default wallpaper
  (`~/Documents/wallpaper/wallpaper-freizeit.jpg` from iCloud Drive; skipped if not synced yet)
- restores the Apache Directory Studio (LDAP) configuration
- installs Claude Code and links its settings (see below)
- installs the git pre-commit hook
- installs the LaunchAgents from `launchagents/` (depending on the Mac role)

Problems that do not stop the run (locked 1Password, missing field, existing
file) are collected and listed at the end. Rerun `./setup.sh` after fixing them.

### Interactive steps

- **Mac role:** `u` = university, `p` = private (asked only once)
- **1Password:** enable `Settings → Developer → Use SSH Agent` and
  `Integrate with 1Password CLI`, then press ENTER
- **Apache Directory Studio:** `Help → Install New Software`,
  `https://directory.apache.org/studio/update/`, install *LDAP Browser*, then press ENTER

---

## 🏷️ Mac role

The role is stored in `~/.mac-role` (`uni` or `privat`) and controls:

- which 1Password WireGuard items are used
- which LaunchAgents are installed: the downloads watcher on every Mac, the
  calendar sync (`com.guido.ms365sync`) only on the private Mac, so that only
  one machine writes to the shared iCloud calendar

---

## 🧠 Commands

| Command | Purpose |
| --- | --- |
| `mode arbeit\|freizeit\|alles\|ich\|status` | Focus mode, wallpaper, running apps, VPN state |
| `vpn start\|stop\|status` | WireGuard tunnels |
| `ms365.sh run\|check` | calendar sync (private Mac only) |
| `drift` | differences between this Mac and GitHub |
| `brewcheck [--add]` | compare installed packages with the `Brewfile` |
| `histsync status` | shell history sync via iCloud |
| `upgrade [--check]` | pull the repo and update software |
| `update` | commit and push local changes |
| `doctor.sh` | health check of the whole setup |

### MS365 / calendar sync (private Mac only)

`sync_calendars.py` (run via `uv`) mirrors the BDV and DDV calendars into the
iCloud calendar "Guido". `ms365sync-run.sh` wraps it for launchd and writes a
status line for `ms365.sh check`.

### Downloads watcher

`watch_downloads.sh` (fswatch, via launchd) moves finished files from
`~/Downloads` to iCloud Drive/Downloads (`sync_downloads.sh`). Log:
`~/Library/Logs/downloads-sync.log`.

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

The generated files are never synced back into the repo (`sync.sh` skips them
on purpose). `doctor.sh` reports missing or unfilled files.

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
`~/.config/mac-setup/forbidden-extra.txt`. Mark a single line deliberately with
`pre-commit:allow` to skip it. Do not bypass the hook with `--no-verify`.
`doctor.sh` checks the setup and runs a self-test.

See also [`SECURITY.md`](SECURITY.md).

---

## 🤖 Claude Code

`setup.sh` installs the Claude Code CLI with Anthropic's native installer
(`https://claude.ai/install.sh`, updates itself) unless `claude` is already
present. The `Brewfile` additionally lists the Claude desktop app.

**`claude/settings.json`** is linked to `~/.claude/settings.json` (user-wide
settings for every project). It contains permission rules that matter because
this repo is public:

- **deny** - Claude may never run `op read`, `op item get`, `op item list`,
  `op inject`, and may not read `~/.ssh/**`, `~/.config/mac-setup/**`
  (forbidden list) or the installed WireGuard configs
- **ask** - confirmation required for `git push`, `rm`, `sudo`,
  `git reset --hard` and `git filter-repo`

If a different `~/.claude/settings.json` already exists, setup does not replace
it and prints a warning; merge the rules by hand or remove the file and rerun
`./setup.sh`. Because it is a symlink, changes made through `/config` or
`/permissions` land directly in the repo and show up in `git status` - review
them before committing. `doctor.sh` checks that the CLI is installed and the
settings are linked.

**`CLAUDE.md`** (in the repo root) holds the project instructions Claude Code
reads in this repo: Mac roles, the hard rules for the public repo, bash 3.2
constraints and the commit routine.

---

## 📡 Drift display

With several Macs, `mac-setup` easily drifts apart. `scripts/drift.sh`
(alias `drift`) shows uncommitted local changes, commits not pushed and new
commits not pulled yet.

- `drift` - full report with a fresh query (exit code 1 on drift)
- iTerm shells run `drift.sh --prompt` at startup (from `dotfiles/.zshrc.iterm`):
  quiet unless there is something to do; the GitHub query (`git ls-remote` over
  HTTPS, hard timeout, no SSH agent / 1Password prompt) runs in the background at
  most every 30 minutes, so a warning appears in the next shell after the query
- `doctor.sh` includes the same check as a warning

It only displays; it never pulls or pushes by itself.

---

## 🍺 Brewfile check

`scripts/brewcheck.sh` (alias `brewcheck`) compares this Mac with the `Brewfile`:

- in the Brewfile but not installed here (`brew bundle check`)
- installed here but not in the Brewfile (`brew bundle cleanup`, dry run only)

`brewcheck --add` offers each unlisted package interactively for the Brewfile
(`y`/`N`/`q`); it never uninstalls anything. Packages that should deliberately
exist on one Mac only go into `~/.config/mac-setup/brew-ignore.txt` (one name
per line, not part of the repo). `doctor.sh` shows the result as a warning.

---

## 📜 Shell history sync (iCloud)

The zsh history is shared between the Macs through iCloud Drive without a
file that two Macs write to (which causes conflict copies and lost lines):

- each Mac publishes only its **own** file:
  `iCloud Drive/shell-history/<computer name>.zsh_history`
- when an iTerm shell starts, `scripts/histsync.sh start` merges the files of the
  other Macs into the local `~/.zsh_history` (deduplicated by timestamp and
  command, sorted by time, at most 50000 entries) and publishes the own file;
  a shell exit publishes it again
- needs `EXTENDED_HISTORY` (set in `dotfiles/.zshrc.iterm`); before the first
  merge `~/.zsh_history.pre-histsync` is saved as a backup
- `histsync status` shows files, entry counts and age

Limits: the history lies unencrypted in iCloud. `HISTORY_IGNORE` skips commands
with obvious secrets (`PASSWORD=`, `TOKEN=`, ...) and commands starting with a
space are never stored - still, do not type secrets on the command line. Entries
from the other Mac appear in the next new shell after iCloud has delivered the
file. A merge replaces the history file, so a command written in the same
millisecond by another tab can get lost (very rare).

---

## 🔄 Keeping Macs in sync

Two directions:

**Repo → this Mac:** `upgrade` (`scripts/upgrade.sh`)

1. `git pull --ff-only` (skipped if tracked files have local changes)
2. `brew update`, `brew upgrade`, `brew upgrade --cask`, `brew cleanup -s`
3. `brew bundle --no-upgrade`: installs packages other Macs added to the Brewfile
4. links new scripts from `scripts/` into `~/bin`
5. shows pending macOS updates (installing stays manual: `sudo softwareupdate -ia`)

At the end it lists what worked, what needs attention and hints such as
"run `./setup.sh` again". `upgrade --check` only reports and changes nothing.
It never runs `setup.sh`, installs macOS updates or uninstalls packages.

**This Mac → repo:**

    update

`update.sh` runs `backup.sh` (macOS preferences + `sync.sh`, which copies
local configs that are not symlinked), shows the changes, asks for
confirmation, commits, then `git pull --rebase` and `git push`.

Dotfiles, Starship, Neovim and the Claude Code settings are symlinks into the
repo, so changes to them are already in the working tree. SSH, WireGuard and
LDAP configs are never synced back. Before committing: `bash -n` on changed
scripts, `./doctor.sh`, `git status`.

---

## 📁 Repository structure

    mac-setup/
    ├── Brewfile              Homebrew packages
    ├── bootstrap.sh          installs Homebrew
    ├── setup.sh              first-time setup / rerun
    ├── doctor.sh             health check
    ├── sync.sh               local configs → repo
    ├── update.sh             commit + push
    ├── backup.sh             macOS preferences + sync.sh
    ├── CLAUDE.md             instructions for Claude Code
    ├── SECURITY.md           security notes
    ├── POST-INSTALL.md       manual checklist after setup
    ├── scripts/              helper scripts (linked to ~/bin)
    ├── dotfiles/             zsh, git, tmux, vim, nano
    ├── config/               Neovim, Starship, iTerm2 profiles
    ├── claude/               Claude Code settings.json
    ├── templates/            1Password templates (WireGuard, LDAP, SSH)
    ├── hooks/                git pre-commit hook
    ├── launchagents/         launchd jobs
    ├── macos/                preference backup / restore
    ├── apache-directory-studio/
    ├── 1password/            SSH agent config
    ├── vscode/               settings, keybindings, extensions
    └── ssh/                  base SSH config
