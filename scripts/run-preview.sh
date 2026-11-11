#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - "$@" <<'PY'
from pathlib import Path
import os
import argparse
import plistlib
import subprocess
import sys
import tempfile

arguments = sys.argv[1:]
parser = argparse.ArgumentParser()
parser.add_argument('--timeline', action='store_true')
parser.add_argument('--menu', action='store_true')
parser.add_argument('--dark', action='store_true')
parser.add_argument('--theme', default='citrus')
parser.add_argument('--state', choices=['idle', 'active', 'paused', 'sleep', 'recovery', 'empty', 'reached'], default='idle')
options = parser.parse_args(arguments)
timeline_preview = options.timeline
name = 'Skeval Menu Preview' if options.menu else ('Skeval Timeline Preview' if timeline_preview else 'Skeval Catch-Up Preview')
executable = 'SkevalMenuPreview' if options.menu else ('SkevalTimelinePreview' if timeline_preview else 'SkevalPreview')
app = Path(tempfile.gettempdir()) / f'{name}.app'
contents = app / 'Contents'
binary = contents / 'MacOS' / executable
binary.parent.mkdir(parents=True, exist_ok=True)
(contents / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.skeval.menu-preview' if options.menu else ('com.skeval.timeline-preview' if timeline_preview else 'com.skeval.v2-catchup-preview'),
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
    # Compile the asset catalog so the preview shows the theme art, like the Xcode build does.
    resources = contents / 'Resources'
    resources.mkdir(parents=True, exist_ok=True)
    subprocess.run(['xcrun', 'actool', 'Skeval Timer/Assets.xcassets', '--compile', str(resources),
                    '--platform', 'macosx', '--minimum-deployment-target', '26.0',
                    '--output-partial-info-plist', str(Path(directory) / 'assets.plist')],
                   env=environment, check=True, stdout=subprocess.DEVNULL)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
subprocess.run(['open', '--env', 'SKEVAL_NO_LIVE_DATA=1', str(app), '--args', *arguments], check=True)
print(f'Opened {app}')
PY
