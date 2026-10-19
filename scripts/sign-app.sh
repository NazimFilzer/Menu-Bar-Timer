#!/usr/bin/env bash
# Preserve the production sandbox identity: without it macOS selects a different log.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:?Usage: bash scripts/sign-app.sh APP [--verify-only]}"
if [[ "${2:-}" != --verify-only ]]; then
  codesign --force --sign - --options runtime --entitlements "$ROOT/scripts/app-entitlements.plist" "$APP"
fi
python3 - "$APP" <<'PY'
import pathlib
import plistlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
result = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)],
                        capture_output=True, check=True)
entitlements = plistlib.loads(result.stdout) if result.stdout.strip() else {}
if info.get('CFBundleIdentifier') != 'com.nazim.Skeval-Timer':
    raise SystemExit('Refusing app with a different production bundle identifier.')
if entitlements.get('com.apple.security.app-sandbox') is not True:
    raise SystemExit('Refusing unsandboxed app: it would load the wrong work history.')
print('PASS: app retains production sandbox identity and data container.')
PY
codesign --verify --strict "$APP"
echo 'PASS: app signature verifies.'
