# Post-Install Checklist

Manual steps after `mac-bootstrap.sh` / `setup.sh` (see [README](README.md)).
First check the warnings `setup.sh` listed at the end; fix them and rerun
`./setup.sh` if needed.

---

## ⚙️ macOS Settings

- [ ] Full Disk Access for iTerm  
      System Settings → Privacy & Security → Full Disk Access → add iTerm

- [ ] Full Disk Access for `/bin/bash` (downloads watcher)  
      System Settings → Privacy & Security → Full Disk Access → `+` → `/bin/bash`  
      (without it the background agent cannot read ~/Downloads or write to iCloud Drive)

- [ ] Adjust Spotlight search

- [ ] Private Mac only: calendar access for the sync  
      Run once and allow the calendar prompt:

      uv run --script ~/bin/sync_calendars.py --dry-run

---

## 🌐 Internet Accounts

- [ ] Google (Mail, Contacts, Calendar)
- [ ] BDV (Mail, Calendar)
- [ ] FIM (Mail)

---

## 📦 Additional Software

- [ ] LRZ Sync+Share  
      https://syncandshare.lrz.de/download_client

---

## 🔐 Logins

- [ ] Google Chrome
- [ ] Firefox
- [ ] Microsoft Edge
- [ ] ChatGPT
- [ ] Claude (desktop app)
- [ ] Mattermost
- [ ] WhatsApp

---

## 🔧 Application Setup

- [ ] Claude Code  
      → run `claude` once and sign in  
      → `/permissions` shows the deny/ask rules from `claude/settings.json`  
      (if setup warned that `~/.claude/settings.json` already exists: merge the rules or remove the file and rerun `./setup.sh`)

- [ ] Apache Directory Studio  
      → verify LDAP connection "Uni LDAP" (host/port/bind DN come from 1Password)  
      → enter password (not stored in the repo)

- [ ] Windows App  
      → import winadmin connection from iCloud  
      → set password and save

- [ ] Calendar  
      → verify calendars are visible

- [ ] KeePassXC  
      → open dummy database (incl. key file) from iCloud

---

## 🧪 System Tests

- [ ] Health check (tools, symlinks, WireGuard, LaunchAgents, Claude Code, hook)

      ./doctor.sh

- [ ] Mode

      mode status
      mode arbeit
      mode freizeit

- [ ] VPN

      vpn start
      vpn status
      vpn stop

- [ ] Downloads watcher: drop a test file into ~/Downloads; it should appear in
      iCloud Drive/Downloads after a few seconds

      tail ~/Library/Logs/downloads-sync.log

- [ ] Private Mac only: calendar sync

      ms365.sh run
      ms365.sh check

- [ ] Repo state

      drift
      brewcheck

---

## ✅ Done

- [ ] Everything works as expected
