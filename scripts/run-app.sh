#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Skeval Timer.xcodeproj"
SCHEME='Skeval Timer'
CONFIGURATION=Debug
DERIVED_DATA="$ROOT/.build/DerivedData"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

usage() {
  cat <<'EOF'
Usage: ./scripts/run-app.sh [--configuration Debug|Release] [--help]

Builds Skeval Timer with Xcode and opens the built app. The default
configuration is Debug. Set DEVELOPER_DIR to use a different Xcode install.
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
if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR. Install Xcode or set DEVELOPER_DIR." >&2
  exit 1
fi
export DEVELOPER_DIR

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Skeval Timer.app"
[[ -d "$APP" ]] || { echo "Build succeeded but app not found: $APP" >&2; exit 1; }
bash "$ROOT/scripts/sign-app.sh" "$APP"
# Do not leave a second writer running against the same production log.
if pgrep -x 'Skeval Timer' >/dev/null; then
  osascript -e 'tell application id "com.nazim.Skeval-Timer" to quit'
  for attempt in {1..50}; do
    if ! pgrep -x 'Skeval Timer' >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -x 'Skeval Timer' >/dev/null; then
    echo 'Timer is still running; refusing to open a second writer.' >&2
    exit 1
  fi
fi
open "$APP"
echo "Opened $APP"
