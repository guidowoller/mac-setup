#!/bin/bash

echo "Running full system backup..."

# macOS settings
bash ~/mac-setup/macos/macos-backup.sh

# sync repo files
bash ~/mac-setup/sync.sh

echo "Backup finished."
