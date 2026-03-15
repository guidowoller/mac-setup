#!/bin/bash

set -e

echo ""
echo "Running system bootstrap..."
echo ""

# ----------------------------
# Homebrew
# ----------------------------

if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

fi

# brew sofort verfügbar machen
if [ -d "/opt/homebrew/bin" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo ""
echo "Homebrew ready."
echo ""

# ----------------------------
# run setup
# ----------------------------

bash setup.sh
