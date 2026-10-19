#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID='com.nazim.Skeval-Timer'
CONTAINER="$HOME/Library/Containers/$BUNDLE_ID/Data"
APP_SUPPORT="$CONTAINER/Library/Application Support/SkevalTimer"
DATA_FILE="$APP_SUPPORT/logs.json"
PREFERENCES="$CONTAINER/Library/Preferences/$BUNDLE_ID.plist"

printf 'Expected app bundle identifier: %s\n' "$BUNDLE_ID"
printf 'Live work log: %s\n' "$DATA_FILE"
printf 'Preferences: %s\n' "$PREFERENCES"
printf '\n'

if [[ -f "$DATA_FILE" ]]; then
  /usr/bin/stat -f 'Log file: %N (%z bytes, modified %Sm)' -t '%Y-%m-%d %H:%M:%S' "$DATA_FILE"
else
  echo 'Log file does not exist at the expected location.'
fi

if [[ -f "$PREFERENCES" ]]; then
  /usr/bin/stat -f 'Preferences file: %N (%z bytes, modified %Sm)' -t '%Y-%m-%d %H:%M:%S' "$PREFERENCES"
else
  echo 'Preferences file does not exist at the expected location.'
fi

if [[ -d '/Applications/Skeval Timer.app' ]]; then
  INSTALLED_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' '/Applications/Skeval Timer.app/Contents/Info.plist' 2>/dev/null || true)
  printf '\nInstalled app bundle identifier: %s\n' "${INSTALLED_ID:-unavailable}"
  bash "$(dirname "$0")/sign-app.sh" '/Applications/Skeval Timer.app' --verify-only
  if [[ "$INSTALLED_ID" != "$BUNDLE_ID" ]]; then
    echo 'WARNING: The installed app bundle identifier differs; it will use a different preferences domain.'
  fi
fi
