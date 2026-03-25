# mac-setup

Personal macOS bootstrap setup.

This repository contains everything required to set up a new Mac quickly:

* Homebrew packages
* shell configuration
* tmux / vim configuration
* scripts
* SSH configuration
* WireGuard templates
* VS Code settings and extensions
* macOS preference restore

---

## Bootstrap a new Mac

Run the bootstrap script:

curl -fsSL https://raw.githubusercontent.com/guidowoller/mac-setup/main/bootstrap.sh | bash

The script will:

1. Install Xcode Command Line Tools
2. Install Homebrew
3. Clone this repository
4. Run setup.sh
5. Install all tools and configuration

---

## WireGuard

WireGuard configuration files are stored as templates.

After setup you must insert your private keys manually.

Edit:

/opt/homebrew/etc/wireguard/*.conf

Private keys are stored in 1Password.

---

## Updating configuration

If you modify your local configuration:

sync-dotfiles

Then commit the changes:

git add .
git commit -m "update config"
git push

---

## Repository structure

mac-setup/
├── Brewfile
├── bootstrap.sh
├── setup.sh
├── sync.sh
├── dotfiles
├── scripts
├── ssh
├── wireguard
├── vscode
└── macos



# mac-setup

## 🚀 Post-Setup Checklist

### 🔐 Einloggen
- [ ] Google Chrome
- [ ] Firefox
- [ ] Microsoft Edge
- [ ] ChatGPT
- [ ] Mattermost
- [ ] Mail (Google Konto)
- [ ] WhatsApp

---

### 📦 Installieren
- [ ] LRZ Sync and Share  
  https://syncandshare.lrz.de/download_client

---

### 🔑 Passwort speichern
- [ ] Apache Directory Studio (Eclipse)
  - [ ] Verbindung öffnen
  - [ ] Passwort eingeben
  - [ ] Passwort speichern

---

### ⚙️ macOS Einstellungen
- [ ] Festplattenvollzugriff aktivieren:
  - System Settings → Privacy & Security → Full Disk Access
  - iTerm hinzufügen

---

## 🛠 DevOps Bootstrap Commands

### 🔄 Update System
```bash
update.sh
