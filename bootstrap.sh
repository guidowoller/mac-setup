#!/bin/bash

set -e

REPO_DIR="$HOME/mac-setup"
REPO_URL="https://github.com/USER/mac-setup.git"

echo ""
echo "Starting macOS bootstrap..."
echo ""

# ----------------------------

# Xcode Command Line Tools

# ----------------------------

echo "Checking for Xcode Command Line Tools..."

if ! xcode-select -p &>/dev/null; then
echo "Installing Xcode Command Line Tools..."
xcode-select --install
echo ""
echo "Please complete the installation and run bootstrap.sh again."
exit 1
fi

# ----------------------------

# Homebrew

# ----------------------------

echo "Checking Homebrew..."

if ! command -v brew >/dev/null 2>&1; then
echo "Installing Homebrew..."

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon path
if [ -d "/opt/homebrew/bin" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
```

else
echo "Homebrew already installed."
fi

# ----------------------------

# Clone or update repo

# ----------------------------

echo "Preparing mac-setup repository..."

if [ ! -d "$REPO_DIR" ]; then
git clone "$REPO_URL" "$REPO_DIR"
else
echo "Repository already exists – updating..."
cd "$REPO_DIR"
git pull
fi

# ----------------------------

# Run setup

# ----------------------------

echo ""
echo "Running setup..."
echo ""

cd "$REPO_DIR"
bash setup.sh

echo ""
echo "Bootstrap complete."
echo ""

