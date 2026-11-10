#!/bin/bash
# ldap-restore.sh - Apache Directory Studio (Eclipse) LDAP-Verbindung wiederherstellen
#
# Hintergrund: Nach einem Eclipse-Update kann der Workspace (~/eclipse-workspace/.metadata)
# neu angelegt werden; dann fehlt connections.xml. Dieses Skript stellt sie aus dem
# 1Password-Template wieder her (gleicher Weg wie setup.sh), ohne das ganze Setup zu laufen.
#
# Aufruf:
#   ldap-restore.sh           wiederherstellen (Eclipse muss beendet sein, 1Password entsperrt)
#   ldap-restore.sh --check   nur pruefen (Exit 0 = vorhanden, 1 = fehlt), ohne 1Password
#   ldap-restore.sh --force   auch ueberschreiben, wenn connections.xml schon existiert

REPO="${MAC_SETUP_REPO:-$HOME/mac-setup}"
WORKSPACE="${ECLIPSE_WORKSPACE:-$HOME/eclipse-workspace}"
PLUGINS="$WORKSPACE/.metadata/.plugins"
CONN_DIR="$PLUGINS/org.apache.directory.studio.connection.core"
CONN_FILE="$CONN_DIR/connections.xml"
TPL="$REPO/templates/ldap-connections.xml.tpl"
SRC="$REPO/apache-directory-studio"

MODE="restore"
case "$1" in
    --check) MODE="check" ;;
    --force) MODE="force" ;;
    "") ;;
    *) echo "Usage: $(basename "$0") [--check|--force]"; exit 2 ;;
esac

if [ "$MODE" = "check" ]; then
    if [ -s "$CONN_FILE" ]; then
        echo "✓ LDAP connections.xml vorhanden"
        exit 0
    fi
    echo "✗ LDAP connections.xml fehlt ($CONN_FILE) - ldap-restore.sh ausfuehren"
    exit 1
fi

if [ ! -f "$TPL" ]; then
    echo "✗ Template nicht gefunden: $TPL"
    exit 1
fi

# Eclipse muss beendet sein, sonst ueberschreibt es die Datei beim Beenden wieder.
# [E] in der Klammer verhindert, dass sich pgrep selbst trifft
if pgrep -x eclipse >/dev/null 2>&1 || pgrep -f '[E]clipse.app/Contents/MacOS/eclipse' >/dev/null 2>&1; then
    echo "✗ Eclipse laeuft noch. Bitte mit Cmd+Q beenden und erneut starten."
    exit 1
fi

if [ -s "$CONN_FILE" ] && [ "$MODE" != "force" ]; then
    echo "✓ connections.xml existiert bereits - nichts zu tun (--force zum Ueberschreiben)"
    exit 0
fi

if ! command -v op >/dev/null 2>&1; then
    echo "✗ 1Password CLI (op) nicht gefunden"
    exit 1
fi

if ! op read "op://University/Mac-Setup Uni/uni/ldap_host" >/dev/null 2>&1; then
    echo "✗ 1Password-Item 'Mac-Setup Uni' nicht lesbar - 1Password entsperren und"
    echo "  'Integrate with 1Password CLI' aktivieren."
    exit 1
fi

mkdir -p "$PLUGINS" "$CONN_DIR" || exit 1

# Statische Teile (Ordner, Browser-Einstellungen) aus dem Repo
if [ -d "$SRC" ]; then
    for d in "$SRC"/org.apache.directory.studio.*; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        mkdir -p "$PLUGINS/$name"
        for f in "$d"/*; do
            [ -f "$f" ] || continue
            # vorhandene Dateien nicht ueberschreiben (Nutzeraenderungen bleiben)
            [ -e "$PLUGINS/$name/$(basename "$f")" ] || cp "$f" "$PLUGINS/$name/"
        done
    done
fi

# Alte Datei sichern, dann ueber temporaere Datei schreiben (nie eine leere XML hinterlassen)
if [ -s "$CONN_FILE" ]; then
    cp "$CONN_FILE" "$CONN_FILE.bak-$(date +%Y%m%d-%H%M%S)"
fi

TMP="$CONN_FILE.new.$$"
if op inject -i "$TPL" > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
    mv "$TMP" "$CONN_FILE"
    chmod 600 "$CONN_FILE"
    echo "✓ LDAP connections.xml wiederhergestellt: $CONN_FILE"
    echo "  Eclipse starten und Verbindung pruefen."
else
    rm -f "$TMP"
    echo "✗ op inject fehlgeschlagen - Feldnamen im Item 'Mac-Setup Uni' pruefen"
    exit 1
fi
