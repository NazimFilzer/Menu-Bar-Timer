#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - "$@" <<'PY'
from pathlib import Path
import os
import plistlib
import subprocess
import sys
import tempfile

arguments = sys.argv[1:]
if arguments not in ([], ['--timeline']):
    raise SystemExit('Usage: scripts/run-preview.sh [--timeline]')

timeline_preview = arguments == ['--timeline']
name = 'Skeval Timeline Preview' if timeline_preview else 'Skeval Catch-Up Preview'
executable = 'SkevalTimelinePreview' if timeline_preview else 'SkevalPreview'
app = Path(tempfile.gettempdir()) / f'{name}.app'
contents = app / 'Contents'
binary = contents / 'MacOS' / executable
binary.parent.mkdir(parents=True, exist_ok=True)
(contents / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.skeval.timeline-preview' if timeline_preview else 'com.skeval.v2-catchup-preview',
    'CFBundleName': name,
    'CFBundleExecutable': executable,
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
subprocess.run(['open', str(app), '--args', *arguments], check=True)
print(f'Opened {app}')
PY
