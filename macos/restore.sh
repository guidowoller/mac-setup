#!/bin/bash

echo "Restoring macOS settings..."

PREF="$HOME/Library/Preferences"
SRC="$HOME/mac-setup/macos/preferences"

# ----------------------------
# Finder
# ----------------------------

if [ -f "$SRC/finder.plist" ]; then
    cp "$SRC/finder.plist" "$PREF/com.apple.finder.plist"
    killall Finder 2>/dev/null
fi

# ----------------------------
# Dock
# ----------------------------

if [ -f "$SRC/dock.plist" ]; then
    cp "$SRC/dock.plist" "$PREF/com.apple.dock.plist"
    killall Dock 2>/dev/null
fi

# ----------------------------
# Screenshot settings
# ----------------------------

if [ -f "$SRC/screencapture.plist" ]; then
    cp "$SRC/screencapture.plist" "$PREF/com.apple.screencapture.plist"
    killall SystemUIServer 2>/dev/null
fi

# ----------------------------
# Global macOS settings
# ----------------------------

if [ -f "$SRC/global.plist" ]; then
    cp "$SRC/global.plist" "$PREF/.GlobalPreferences.plist"
fi

# ----------------------------
# iTerm2
# ----------------------------

if [ -f "$SRC/iterm2.plist" ]; then
    cp "$SRC/iterm2.plist" "$PREF/com.googlecode.iterm2.plist"
fi

echo "Configuring desktop behavior..."

# Desktop icons OFF
defaults write com.apple.finder CreateDesktop -bool false

# Widgets OFF (desktop)
defaults write com.apple.WindowManager StandardHideWidgets -bool true

# Widgets OFF (Stage Manager)
defaults write com.apple.WindowManager StageManagerHideWidgets -bool true

killall Finder || true
killall Dock || true

echo "Settings restored."
