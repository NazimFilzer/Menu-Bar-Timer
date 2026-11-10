#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID='com.nazim.Skeval-Timer'
CONTAINER="$HOME/Library/Containers/$BUNDLE_ID/Data"
APP_SUPPORT="$CONTAINER/Library/Application Support/SkevalTimer"
DATA_FILE="$APP_SUPPORT/logs.json"
PREFERENCES="$CONTAINER/Library/Preferences/$BUNDLE_ID.plist"

printf 'Expected app bundle identifier: %s\n' "$BUNDLE_ID"
printf 'Live data folder: %s\n' "$APP_SUPPORT"
printf 'Preferences: %s\n' "$PREFERENCES"
printf '\n'

REGISTRY="$APP_SUPPORT/profiles.json"
if [[ -f "$REGISTRY" ]]; then
  printf 'Profiles registry: %s\n' "$REGISTRY"
  /usr/bin/python3 -c '
import json, os, sys
registry = json.load(open(sys.argv[1]))
for profile in registry.get("profiles", []):
    log = os.path.join(sys.argv[2], profile["id"], "logs.json")
    active = " (active)" if profile["id"] == registry.get("activeID") else ""
    size = f"{os.path.getsize(log)} bytes" if os.path.exists(log) else "no log yet"
    name = profile["name"]
    print(f"  {name}{active}: {log} ({size})")
' "$REGISTRY" "$APP_SUPPORT/Profiles"
  if [[ -f "$DATA_FILE" ]]; then
    echo "WARNING: $DATA_FILE still exists; it is no longer read once profiles.json exists."
  fi
elif [[ -f "$DATA_FILE" ]]; then
  /usr/bin/stat -f 'Log file (before profiles): %N (%z bytes, modified %Sm)' -t '%Y-%m-%d %H:%M:%S' "$DATA_FILE"
  echo 'The next launch moves it into the "Skeval" profile and keeps the original in Backups/.'
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
