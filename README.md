# mac-setup

Personal macOS bootstrap setup.

This repository contains everything required to set up a new Mac quickly and reproducibly:

- Homebrew packages
- shell configuration
- tmux / vim / nvim configuration
- scripts (mode, vpn, ms365)
- SSH configuration
- WireGuard templates
- VS Code settings and extensions
- macOS preference restore
- Apache Directory Studio configuration

---

## 🚀 Bootstrap a new Mac

Run the bootstrap script:

    curl -fsSL https://raw.githubusercontent.com/guidowoller/mac-setup/main/bootstrap.sh | bash

This will:

1. Install Xcode Command Line Tools  
2. Install Homebrew  
3. Clone this repository  
4. Run `setup.sh`  
5. Install all tools and configuration  

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

## 🔐 WireGuard

WireGuard configs are generated during setup.

Private keys and IPs are automatically pulled from 1Password.

Configs are stored in:

    /opt/homebrew/etc/wireguard/

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
    ├── wireguard
    ├── apache-directory-studio
    ├── vscode
    ├── macos
    └── ssh

---

## 📋 Post-Install Checklist

See:

    POST-INSTALL.md

This file is intended as a temporary checklist and can be deleted after setup is complete.
