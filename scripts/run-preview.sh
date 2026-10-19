#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import os
import plistlib
import subprocess
import tempfile

app = Path(tempfile.gettempdir()) / 'Skeval Catch-Up Preview.app'
contents = app / 'Contents'
binary = contents / 'MacOS' / 'SkevalPreview'
binary.parent.mkdir(parents=True, exist_ok=True)
(contents / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.skeval.v2-catchup-preview',
    'CFBundleName': 'Skeval Catch-Up Preview',
    'CFBundleExecutable': 'SkevalPreview',
    'CFBundlePackageType': 'APPL',
    'NSHighResolutionCapable': True,
}))
environment = os.environ.copy()
environment.setdefault('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')
sources = sorted(str(path) for path in Path('Skeval Timer').glob('*.swift')
                 if path.name not in ('ContentView.swift', 'Skeval_TimerApp.swift'))
with tempfile.TemporaryDirectory(prefix='skeval-preview-') as directory:
    source = Path('Skeval Timer/Skeval_TimerApp.swift').read_text()
    start = source.index('@main\nstruct SkevalTimerApp')
    end = source.index('@MainActor\nclass AppDelegate')
    delegate = Path(directory) / 'AppDelegate.swift'
    delegate.write_text(source[:start] + source[end:])
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', *sources, str(delegate),
                    'Preview/PreviewMain.swift', '-o', str(binary)], env=environment, check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
subprocess.run(['open', str(app)], check=True)
print(f'Opened {app}')
PY
