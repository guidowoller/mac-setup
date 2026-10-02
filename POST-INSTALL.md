# Post-Install Checklist

Follow this checklist after running `bootstrap.sh` and `setup.sh`.

---

## ⚙️ macOS Settings

- [ ] Enable Full Disk Access  
      System Settings → Privacy & Security → Full Disk Access  
      Add: iTerm

- [ ] Adjust Spotlight Search

- [ ] Downloads watcher: grant Full Disk Access to `/bin/bash`  
      System Settings → Privacy & Security → Full Disk Access → `+` → `/bin/bash`  
      (without it the background agent cannot read ~/Downloads or write to iCloud Drive)

- [ ] Private Mac only: calendar sync access  
      Run once in a terminal and allow the calendar prompt:

      uv run --script ~/bin/sync_calendars.py --dry-run

---

## 🌐 Internet Accounts

- [ ] Google (Mail, Contacts, Calendar)
- [ ] BDV (Mail, Calendar)
- [ ] FIM (Mail)

---

## 📦 Additional Software

- [ ] Install LRZ Sync+Share  
      https://syncandshare.lrz.de/download_client

---

## 🔐 Logins

- [ ] Google Chrome
- [ ] Firefox
- [ ] Microsoft Edge
- [ ] ChatGPT
- [ ] Mattermost
- [ ] WhatsApp

---

## 🔧 Application Setup

- [ ] Apache Directory Studio  
      → verify LDAP connection "Uni LDAP" (host/port/bind DN come from 1Password)  
      → enter password (not stored in the repo)

- [ ] Windows App  
      → import winadmin connection from iCloud
      → set password and save

- [ ] Calendar  
      → verify calendars are visible

- [ ] KeePassXC  
      → open dummy database (incl. key file) from icloud

---

## 🧪 System Tests

- [ ] Check mode status

      mode status

- [ ] Check VPN status

      vpn status

- [ ] Run `doctor.sh` (checks tools, symlinks, WireGuard, LaunchAgents)

      doctor.sh

- [ ] Downloads watcher: drop a test file into ~/Downloads, it should appear in iCloud Drive/Downloads after a few seconds

      tail ~/Library/Logs/downloads-sync.log

- [ ] Private Mac only: run MS365 / calendar sync

      ms365.sh run
      ms365.sh check

- [ ] Test VPN

      vpn start
      vpn status

- [ ] Test mode switching

      mode arbeit
      mode freizeit

---

## ✅ Done

- [ ] Everything works as expected

You can now delete this file if desired.
