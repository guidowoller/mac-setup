#!/bin/bash

echo "Restoring macOS settings..."

defaults import com.apple.dock ~/mac-setup/macos/preferences/dock.plist
defaults import com.apple.finder ~/mac-setup/macos/preferences/finder.plist
defaults import com.apple.screencapture ~/mac-setup/macos/preferences/screencapture.plist
defaults import NSGlobalDomain ~/mac-setup/macos/preferences/global.plist
defaults import com.googlecode.iterm2 ~/mac-setup/macos/preferences/iterm2.plist

killall Dock
killall Finder

echo "Settings restored."

