#!/bin/bash

set -e

echo "Installing Xcode Command Line Tools..."

if ! xcode-select -p &>/dev/null; then
xcode-select --install
echo "Please complete the installation and re-run bootstrap."
exit 1
fi

echo "Installing Homebrew..."

if ! command -v brew &>/dev/null; then
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Cloning mac setup repository..."

if [ ! -d "$HOME/mac-setup" ]; then
git clone https://github.com/USER/mac-setup.git ~/mac-setup
fi

cd ~/mac-setup

bash setup.sh

