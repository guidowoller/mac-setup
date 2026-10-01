#!/bin/bash
#
# bootstrap.sh - zweiter Schritt nach dem Klonen
#
# Wird von ~/iCloud Drive/bootstrap/mac-bootstrap.sh aufgerufen, nachdem das
# Repo nach ~/mac-setup geklont wurde. Installiert Homebrew und startet setup.sh.
# (Der Homebrew-Installer richtet bei Bedarf auch die Xcode Command Line Tools ein.)

set -e

cd "$(cd "$(dirname "$0")" && pwd)"

if [ ! -f setup.sh ]; then
    echo "setup.sh nicht gefunden. Bitte mac-bootstrap.sh aus dem iCloud-Ordner 'bootstrap' starten." >&2
    exit 1
fi

echo ""
echo "Running system bootstrap..."
echo ""

# ----------------------------
# Homebrew
# ----------------------------

if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
    echo "Installing Homebrew..."

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# brew sofort verfuegbar machen
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo ""
echo "Homebrew ready."
echo ""

# ----------------------------
# run setup
# ----------------------------

bash setup.sh
