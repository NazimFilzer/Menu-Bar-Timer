#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Skeval Timer.xcodeproj"
SCHEME='Skeval Timer'
CONFIGURATION=Debug
DERIVED_DATA="$ROOT/.build/DerivedData"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUNDLE_ID='com.nazim.Skeval-Timer'

usage() {
  cat <<'EOF'
Usage: ./scripts/run-app.sh [--configuration Debug|Release] [--help]

Builds and signs the app in .build/DerivedData, then quits any running copy
and launches the newly built app. It does not install the app in /Applications.
The default configuration is Debug.
Set DEVELOPER_DIR to use a different Xcode install.
EOF
}

while (($#)); do
  case "$1" in
    --configuration)
      (($# >= 2)) || { echo 'Missing value for --configuration' >&2; exit 2; }
      CONFIGURATION="$2"
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

if [[ "$CONFIGURATION" != Debug && "$CONFIGURATION" != Release ]]; then
  echo 'Configuration must be Debug or Release.' >&2
  exit 2
fi
if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  DEVELOPER_DIR="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
fi
if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Xcode not found. Install Xcode or set DEVELOPER_DIR to its Developer directory." >&2
  exit 1
fi
export DEVELOPER_DIR

# Keep Debug code in the executable so ad-hoc signing works with hardened runtime.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_DEBUG_DYLIB=NO \
  build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Skeval Timer.app"
[[ -d "$APP" ]] || { echo "Build succeeded but app not found: $APP" >&2; exit 1; }
bash "$ROOT/scripts/sign-app.sh" "$APP"

# Do not leave a second writer running against the same production log.
if /usr/bin/pgrep -x 'Skeval Timer' >/dev/null; then
  /usr/bin/osascript -e "tell application id \"$BUNDLE_ID\" to quit" || true
  for attempt in {1..50}; do
    if ! /usr/bin/pgrep -x 'Skeval Timer' >/dev/null; then break; fi
    sleep 0.1
  done
  if /usr/bin/pgrep -x 'Skeval Timer' >/dev/null; then
    echo 'Timer is still running; refusing to open a second writer.' >&2
    exit 1
  fi
fi

/usr/bin/open "$APP"

for attempt in {1..50}; do
  PID="$(/usr/bin/pgrep -x 'Skeval Timer' || true)"
  if [[ -n "$PID" ]]; then
    # A process can appear briefly before a launch crash. Confirm the built copy survives.
    sleep 2
    if [[ "$(/bin/ps -p "$PID" -o comm=)" != "$APP/Contents/MacOS/Skeval Timer" ]]; then
      echo "The newly built app did not stay running: $APP" >&2
      exit 1
    fi
    echo "Running: $APP"
    exit 0
  fi
  sleep 0.1
done
echo "Launch requested but no Skeval Timer process appeared: $APP" >&2
exit 1
