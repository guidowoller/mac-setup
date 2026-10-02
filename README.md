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
    ├── apache-directory-studio
    ├── vscode
    ├── macos
    └── ssh

---

## 📋 Post-Install Checklist

See:

    POST-INSTALL.md

This file is intended as a temporary checklist and can be deleted after setup is complete.
