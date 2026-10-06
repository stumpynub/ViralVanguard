#!/usr/bin/env bash
# Exports the web build and packages it for itch.io: build/viral-vanguard-web.zip (upload as an HTML5 game).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/Documents/Godot/Godot_v4.7.2-stable_linux.x86_64}"
mkdir -p build/web
touch build/.gdignore
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
rm -f build/web/*.import build/viral-vanguard-web.zip
(cd build/web && python3 -c "
import zipfile, os
with zipfile.ZipFile('../viral-vanguard-web.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in sorted(os.listdir('.')):
        z.write(f, f)
")
ls -lh build/viral-vanguard-web.zip
