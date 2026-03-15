#!/bin/bash

echo "Backing up macOS settings..."

SRC="$HOME/Library/Preferences"
DEST="$HOME/mac-setup/macos/preferences"

mkdir -p "$DEST"

# ----------------------------
# ensure preferences are written
# ----------------------------

killall Dock 2>/dev/null
killall Finder 2>/dev/null
killall SystemUIServer 2>/dev/null

sleep 1

# ----------------------------
# backup preferences
# ----------------------------

cp "$SRC/com.apple.dock.plist" "$DEST/dock.plist"
cp "$SRC/com.apple.finder.plist" "$DEST/finder.plist"
cp "$SRC/com.apple.screencapture.plist" "$DEST/screencapture.plist"
cp "$SRC/.GlobalPreferences.plist" "$DEST/global.plist"
cp "$SRC/com.googlecode.iterm2.plist" "$DEST/iterm2.plist"

echo "Backup complete."
