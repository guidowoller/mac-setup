#!/bin/bash

echo ""
echo "Closing user applications..."
echo ""

EXCLUDE=(
"Finder"
"Terminal"
"iTerm2"
"System Settings"
"Dock"
)

apps=$(osascript <<EOF
tell application "System Events"
set appList to name of every application process whose background only is false
end tell
return appList
EOF
)

apps=$(echo "$apps" | tr ',' '\n' | sed 's/^ *//')

while IFS= read -r app; do

skip=false

for ex in "${EXCLUDE[@]}"; do
    if [[ "$app" == "$ex" ]]; then
        skip=true
    fi
done

if [ "$skip" = false ]; then

echo "Closing $app"

osascript -e "tell application \"$app\" to quit" 2>/dev/null

sleep 2

if pgrep -x "$app" >/dev/null; then
    echo "Force quitting $app"
    pkill -x "$app"
fi

fi

done <<< "$apps"

echo ""
echo "Done."
echo ""
