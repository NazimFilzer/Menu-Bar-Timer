#!/usr/bin/env bash
# Renders the app's 3D art for all 24 theme palettes into Assets.xcassets/Art3D.
# Accents are read from AppTheme.swift, so a new or changed theme only needs a rerun.
set -euo pipefail
cd "$(dirname "$0")/.."
target="Skeval Timer/Assets.xcassets/Art3D"
mkdir -p "$target"
printf '{"info":{"author":"xcode","version":1},"properties":{"provides-namespace":false}}\n' > "$target/Contents.json"
specs=$(python3 -I - <<'PY'
import re
from pathlib import Path
source = Path("Skeval Timer/AppTheme.swift").read_text()
# Each palette: name, isLight (default true for the first block), and accentColor.
pattern = re.compile(r'PopoverTheme\(\s*name: "([^"]+)"(?:, isLight: (true|false))?.*?accentColor: Color\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\)', re.S)
seen = set()
for name, light, r, g, b in pattern.findall(source):
    mode = "dark" if light == "false" else "light"
    slug = f"{name.lower()}-{mode}"
    if slug in seen:
        continue
    seen.add(slug)
    hexcode = "".join(f"{round(float(v) * 255):02X}" for v in (r, g, b))
    print(f"{slug}={hexcode}")
PY
)
count=$(echo "$specs" | wc -l | tr -d ' ')
echo "Rendering $count palettes into $target"
# shellcheck disable=SC2086
swift scripts/render-3d-assets.swift --app "$target" $specs
