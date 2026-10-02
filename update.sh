#!/bin/bash
# update.sh - Repo-Stand sichern: backup -> pull --rebase -> commit -> push
set -e

REPO="$HOME/mac-setup"
cd "$REPO"

echo ""
echo "Updating mac setup repository..."
echo ""

echo "Running backup..."
bash "$REPO/backup.sh"

# Aenderungen anzeigen und bestaetigen (kein blindes 'git add .')
if [ -n "$(git status --porcelain)" ]; then
    echo ""
    git status --short
    echo ""
    if [ -t 0 ]; then
        read -r -p "Alle diese Aenderungen committen? [j/N] " ans
        case "$ans" in j|J|y|Y) ;; *) echo "Abgebrochen."; exit 1;; esac
    fi
    git add -A
    # Der pre-commit-Hook prueft auf verbotene Inhalte; bei Fehler bricht set -e ab.
    git commit -m "update mac setup"
else
    echo "No changes to commit."
fi

# Erst holen, dann pushen (mehrere Macs)
git pull --rebase
git push

echo ""
echo "Update complete."
echo ""
