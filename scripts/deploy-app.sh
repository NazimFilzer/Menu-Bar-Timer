#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Skeval Timer.xcodeproj"
SCHEME='Skeval Timer'
CONFIGURATION=Release
DESTINATION='/Applications/Skeval Timer.app'
DERIVED_DATA="$ROOT/.build/DeployDerivedData"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUNDLE_ID='com.nazim.Skeval-Timer'
DATA_FILE="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Application Support/SkevalTimer/logs.json"

usage() {
  cat <<'EOF'
Usage: ./scripts/deploy-app.sh [--destination /Applications/Skeval\ Timer.app] [--help]

Builds a Release app, stages it before replacing the destination, then opens it.
The timer's logs and preferences remain in your user Library, not inside the app.
Set DEVELOPER_DIR to use a different Xcode install.
EOF
}

while (($#)); do
  case "$1" in
    --destination)
      (($# >= 2)) || { echo 'Missing value for --destination' >&2; exit 2; }
      DESTINATION="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR. Install Xcode or set DEVELOPER_DIR." >&2
  exit 1
fi
if [[ "$DESTINATION" != /* || "$DESTINATION" == '/' || "$DESTINATION" == "$ROOT"/* ]]; then
  echo 'Destination must be an absolute app path outside the project directory.' >&2
  exit 2
fi
if [[ "$DESTINATION" != *.app ]]; then
  echo 'Destination must end in .app.' >&2
  exit 2
fi

PARENT="$(dirname "$DESTINATION")"
APP_NAME="$(basename "$DESTINATION")"
STAMP="$(date '+%Y%m%d-%H%M%S')"
STAGED="$PARENT/.${APP_NAME%.app}-staged-$STAMP.app"
BACKUP="$PARENT/${APP_NAME%.app}-backup-$STAMP.app"

export DEVELOPER_DIR
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$ROOT/.build/DeployDerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build

BUILT_APP="$ROOT/.build/DeployDerivedData/Build/Products/$CONFIGURATION/Skeval Timer.app"
[[ -d "$BUILT_APP" ]] || { echo "Build succeeded but app not found: $BUILT_APP" >&2; exit 1; }
BUILT_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILT_APP/Contents/Info.plist")
[[ "$BUILT_ID" == "$BUNDLE_ID" ]] || {
  echo "Refusing to install unexpected bundle identifier '$BUILT_ID' (expected '$BUNDLE_ID')." >&2
  exit 1
}
printf 'Preserving user data at: %s\\n' "$DATA_FILE"
if [[ -f "$DATA_FILE" ]]; then
  /usr/bin/stat -f 'Current log: %N (%z bytes, modified %Sm)' -t '%Y-%m-%d %H:%M:%S' "$DATA_FILE"
else
  echo 'No log file found at the live-data location; deployment will not create or import one.'
fi
mkdir -p "$PARENT"
[[ ! -e "$STAGED" && ! -e "$BACKUP" ]] || { echo 'Refusing to overwrite a staging or backup path.' >&2; exit 1; }

cleanup() {
  if [[ -e "$STAGED" ]]; then
    rm -rf "$STAGED"
  fi
  if [[ -d "$BACKUP" && ! -e "$DESTINATION" ]]; then
    ditto "$BACKUP" "$DESTINATION"
    echo "Restored previous app from $BACKUP" >&2
  fi
}
trap cleanup EXIT

# Prepare and verify a full copy before stopping or replacing the installed app.
ditto "$BUILT_APP" "$STAGED"
[[ -x "$STAGED/Contents/MacOS/Skeval Timer" ]] || { echo 'Staged app executable is missing.' >&2; exit 1; }
bash "$ROOT/scripts/sign-app.sh" "$STAGED"

# Stop the target app only after a successful build and staged copy.
if [[ -d "$DESTINATION" ]]; then
  INSTALLED_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist")
  if pgrep -x 'Skeval Timer' >/dev/null; then
    /usr/bin/osascript -e "tell application id \"$INSTALLED_ID\" to quit"
  fi
  for attempt in {1..50}; do
    if ! pgrep -x 'Skeval Timer' >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -x 'Skeval Timer' >/dev/null; then
    echo 'Timer is still running; refusing to replace it.' >&2
    exit 1
  fi
  # Keep a snapshot of the actual production data, never the stale legacy path.
  DATA_BACKUP="$ROOT/artifacts/deploy-data-$STAMP"
  mkdir -p "$DATA_BACKUP"
  if [[ -d "$(dirname "$DATA_FILE")" ]]; then
    ditto "$(dirname "$DATA_FILE")" "$DATA_BACKUP/logs"
  fi
  PREFS="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Preferences/$BUNDLE_ID.plist"
  if [[ -f "$PREFS" ]]; then
    ditto "$PREFS" "$DATA_BACKUP/preferences.plist"
  fi
  ditto "$DESTINATION" "$BACKUP"
  rm -rf "$DESTINATION"
fi

ditto "$STAGED" "$DESTINATION"
rm -rf "$STAGED"
trap - EXIT
open "$DESTINATION"
echo "Installed and opened $DESTINATION"
if [[ -d "$BACKUP" ]]; then
  echo "Previous app backup: $BACKUP"
fi
