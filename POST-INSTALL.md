# Post-Install Checklist

Follow this checklist after running `bootstrap.sh` and `setup.sh`.

---

## ⚙️ macOS Settings

- [ ] Enable Full Disk Access  
      System Settings → Privacy & Security → Full Disk Access  
      Add: iTerm

- [ ] Adjust Spotlight Search

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
      → verify LDAP connections  
      → enter passwords if required

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

- [ ] Run MS365 sync

      ms365.sh run

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
