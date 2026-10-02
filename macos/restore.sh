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

# Frueher wurde die komplette .GlobalPreferences.plist gesichert und zurueckkopiert.
# Darin standen aber auch persoenliche Daten (Textersetzungen mit E-Mail-Adressen),
# deshalb werden hier nur noch die gewollten Einstellungen einzeln gesetzt.
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true
defaults write -g AppleShowAllExtensions -bool true
defaults write -g AppleMiniaturizeOnDoubleClick -bool false
defaults write -g NSAutomaticCapitalizationEnabled -bool true
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool true
defaults write -g com.apple.sound.beep.flash -int 0
defaults write -g com.apple.springing.enabled -bool true
defaults write -g com.apple.springing.delay -float 0.5
defaults write -g com.apple.swipescrolldirection -bool false
defaults write -g com.apple.trackpad.forceClick -bool true

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
