#!/bin/bash

mkdir -p ~/mac-setup/macos/preferences

echo "Backing up macOS settings..."

defaults read com.apple.dock > ~/mac-setup/macos/preferences/dock.plist
defaults read com.apple.finder > ~/mac-setup/macos/preferences/finder.plist
defaults read com.apple.screencapture > ~/mac-setup/macos/preferences/screencapture.plist
defaults read NSGlobalDomain > ~/mac-setup/macos/preferences/global.plist
defaults read com.googlecode.iterm2 > ~/mac-setup/macos/preferences/iterm2.plist

echo "Backup complete."

