#!/bin/bash
#
# Erzeugt die Verbotsliste fuer den pre-commit-Hook aus dem 1Password-Item
# "Mac-Setup Uni" (Vault University):  ~/.config/mac-setup/forbidden.txt
# Die Liste enthaelt echte Werte und darf NIE ins Repo. Rechte: 600.
#
# Aufruf: bash hooks/update-forbidden.sh

set -euo pipefail

ITEM="Mac-Setup Uni"
VAULT="University"
OUT_DIR="$HOME/.config/mac-setup"
OUT="$OUT_DIR/forbidden.txt"

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

if ! JSON=$(op item get "$ITEM" --vault "$VAULT" --format json 2>/dev/null); then
    echo "1Password-Item '$ITEM' (Vault $VAULT) nicht lesbar - 1Password entsperrt und CLI-Integration aktiv?" >&2
    exit 1
fi

printf '%s' "$JSON" | python3 -c '
import sys, json
SKIP = {"ldap_port", "uni_ssh_user", "notesPlain"}
data = json.load(sys.stdin)
terms = set()

def add(t):
    t = (t or "").strip()
    if len(t) >= 5:
        terms.add(t)

def domain_suffix(host):
    parts = host.split(".")
    if len(parts) >= 3 and not all(p.isdigit() for p in parts):
        add(".".join(parts[-2:]))

for f in data.get("fields", []):
    label = f.get("label", "")
    value = (f.get("value") or "").strip()
    if not value or label in SKIP:
        continue
    if label.endswith("_peer_public_key"):
        add(value); add(value.rstrip("="))
    elif label.endswith("_endpoint"):
        host = value.rsplit(":", 1)[0]
        add(host); domain_suffix(host)
    elif label.endswith("_allowed_ips"):
        for entry in value.split(","):
            entry = entry.strip(); add(entry); add(entry.split("/")[0])
    elif label == "ldap_bind_dn":
        add(value)
        i = value.lower().find("dc=")
        if i >= 0:
            add(value[i:])
    elif label in ("ldap_host", "uni_ssh_host"):
        add(value); domain_suffix(value)
    else:
        add(value)

for t in sorted(terms):
    print(t)
' > "$OUT.tmp"

mv "$OUT.tmp" "$OUT"
chmod 600 "$OUT"
echo "→ $(grep -c . "$OUT") Begriffe in $OUT (nicht im Repo)"
