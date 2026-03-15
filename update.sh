#!/bin/bash

set -e

REPO="$HOME/mac-setup"

echo ""
echo "Updating mac setup repository..."
echo ""

cd "$REPO"

# run backup
echo "Running backup..."
bash "$REPO/backup.sh"

# stage changes
git add .

# commit only if there are changes
if ! git diff --cached --quiet; then
    echo "Creating commit..."
    git commit -m "update mac setup ($(hostname))"
else
    echo "No changes to commit."
fi

# push
git push

echo ""
echo "Update complete."
echo ""
