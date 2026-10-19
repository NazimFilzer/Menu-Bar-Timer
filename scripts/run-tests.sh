#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import os
import subprocess
import tempfile

with tempfile.TemporaryDirectory(prefix='skeval-tests-') as directory:
    temporary = Path(directory)
    sources = sorted(str(path) for path in Path('Skeval Timer').glob('*.swift')
                     if path.name not in ('ContentView.swift', 'Skeval_TimerApp.swift'))
    # Compile the real app delegate without the app's entry point, so TestMain can run.
    app_source = Path('Skeval Timer/Skeval_TimerApp.swift').read_text()
    start = app_source.index('@main\nstruct SkevalTimerApp')
    end = app_source.index('@MainActor\nclass AppDelegate')
    delegate = temporary / 'AppDelegate.swift'
    delegate.write_text(app_source[:start] + app_source[end:])
    binary = temporary / 'SkevalTests'
    environment = os.environ.copy()
    xcode = '/Applications/Xcode.app/Contents/Developer'
    if Path(xcode).exists():
        environment.setdefault('DEVELOPER_DIR', xcode)
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', *sources,
                    str(delegate), *sorted(str(path) for path in Path('Tests').glob('*.swift')),
                    '-o', str(binary)],
                   env=environment, check=True)
    subprocess.run([str(binary)], env=environment, check=True)
PY
