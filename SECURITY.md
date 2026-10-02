# Security Notes

## ⚠️ Kompromittierte WireGuard-Keys in der Git-History

### Problem

In der Git-History dieses Repos (Commit `e27bec7` und folgende) wurden zwei
echte WireGuard Private Keys committed, bevor sie durch Platzhalter ersetzt
wurden:

```
PrivateKey = <REMOVED>=   # wg-faith
PrivateKey = <REMOVED>=   # wg-fim5
```

Ebenso waren die zugehörigen IP-Adressen (Client-Adressen der VPN-Tunnel)
kurz im Klartext in der History. Obwohl die aktuellen Dateien saubere
Platzhalter enthalten, sind die alten Werte weiterhin über `git log -p`
abrufbar.

---

### Sofortmaßnahmen

#### 1. WireGuard-Keys rotieren

Da die alten Keys kompromittiert sind, müssen neue Keypairs generiert und
beim jeweiligen WireGuard-Server (FIM-IT) registriert werden:

```bash
# Neues Keypair generieren
wg genkey | tee /tmp/wg_new_private.key | wg pubkey > /tmp/wg_new_public.key

cat /tmp/wg_new_public.key   # → beim FIM-IT als neuen Public Key registrieren
cat /tmp/wg_new_private.key  # → in 1Password hinterlegen, dann löschen
rm /tmp/wg_new_private.key /tmp/wg_new_public.key
```

Das gilt für **beide** VPN-Verbindungen (wg-fim5 und wg-faith).

#### 2. Git-History bereinigen

Nach der Key-Rotation die History reschreiben, um die alten Keys zu entfernen.

Voraussetzung: `git-filter-repo` installieren:

```bash
brew install git-filter-repo
```

Dann sensitive Werte aus der gesamten History entfernen:

```bash
cd ~/mac-setup

git filter-repo --force \
  --replace-text <(cat <<'REPLACEMENTS'
<REMOVED>==><REMOVED>
<REMOVED>==><REMOVED>
<alte-IP-1>=><ENTER_IP_ADDRESS_HERE>
<alte-IP-2>=><ENTER_IP_ADDRESS_HERE>
REPLACEMENTS
)
```

Danach den Remote neu setzen und force-pushen:

```bash
git remote add origin git@github.com:guidowoller/mac-setup.git
git push -u --force origin main   # -u setzt den Upstream (filter-repo entfernt die Branch-Tracking-Konfiguration)
git push --force --tags
```

> `git filter-repo` entfernt `origin` und die Tracking-Konfiguration. Ohne `-u` meldet
> `git pull` später „There is no tracking information for the current branch“.
> Nachträglich beheben: `git branch --set-upstream-to=origin/main main`

> **Hinweis:** Alle anderen Klone des Repos müssen danach neu geclont werden –
> `git pull` reicht nach einem History-Rewrite nicht.

---

### Dauerhaft verhindern

`sync.sh` anonymisiert jetzt beide sensitiven Felder beim Zurückschreiben:

```bash
sed -e 's/^PrivateKey.*/PrivateKey = <ENTER_PRIVATE_KEY_HERE>/' \
    -e 's/^Address.*/Address = <ENTER_IP_ADDRESS_HERE>/' \
    "$f" > "$WG_DST/$fname"
```

Die echten Werte kommen ausschließlich zur Laufzeit aus 1Password (`op item get`).

---

## Uni-Infrastrukturdaten nicht mehr im Repo

WireGuard-Peers (PublicKey, Endpoint, AllowedIPs), LDAP-Host/-Port/-Bind-DN und
SSH-Host/-User stehen nicht mehr im Repository, sondern im 1Password-Item
`Mac-Setup Uni` (Vault `University`). Im Repo liegen nur Vorlagen
(`templates/*.tpl`) mit `{{ op://... }}`-Referenzen, die `setup.sh` per
`op inject` fuellt.

Wichtig: Die **Git-History** enthaelt diese Werte weiterhin (alte Commits).
Das Entfernen aus dem aktuellen Stand ersetzt keinen History-Rewrite. Die
Daten sind keine Zugangsdaten, erleichtern aber das Kartieren der Infrastruktur.
