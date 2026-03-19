#!/bin/bash

start_minimized() {
  APP="$1"
  shift

  # starten (mit optionalen args)
  if [ $# -gt 0 ]; then
    open -a "$APP" --args "$@"
  else
    open -a "$APP"
  fi

  osascript <<EOF
tell application "System Events"
    repeat until exists (process "$APP")
        delay 0.2
    end repeat
end tell

tell application "$APP" to activate

delay 0.5

tell application "System Events"
    tell process "$APP"
        try
            keystroke "m" using {command down}
        end try
    end tell
end tell
EOF
}

start_normal() {
  APP="$1"
  shift

  if [ $# -gt 0 ]; then
    open -a "$APP" --args "$@"
  else
    open -a "$APP"
  fi
}

start_fullscreen() {
  APP="$1"
  shift

  # starten mit optionalen args
  if [ $# -gt 0 ]; then
    open -a "$APP" --args "$@"
  else
    open -a "$APP"
  fi

  osascript <<EOF
tell application "System Events"
    repeat until exists (process "$APP")
        delay 0.2
    end repeat
end tell

tell application "$APP" to activate

delay 0.8

tell application "System Events"
    tell process "$APP"
        try
            keystroke "f" using {control down, command down}
        end try
    end tell
end tell
EOF
}

# Nutzung
echo "Starting applications..."
start_minimized "KeePassXC" --allow-screencapture
start_fullscreen "Firefox"
