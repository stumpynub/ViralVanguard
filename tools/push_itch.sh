#!/usr/bin/env bash
# Exports the web build and uploads it to itch.io with butler (incremental: later pushes only send what changed).
#   ITCH_TARGET=yourname/scifi ./tools/push_itch.sh
# The itch project page must exist first (itch.io → Dashboard → Create new project, Kind of project: HTML).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ITCH_TARGET:?set ITCH_TARGET=username/game, e.g. ITCH_TARGET=joshua/scifi}"
BUTLER="${BUTLER:-$HOME/Documents/itch/butler/butler-linux-amd64/butler}"
CHANNEL="${ITCH_CHANNEL:-html5}"     # a channel name containing "html5" tags the upload as a browser game
./tools/export_web.sh
VERSION="$(date +%Y.%m.%d-%H%M)"
"$BUTLER" push build/web "$ITCH_TARGET:$CHANNEL" --userversion "$VERSION"
"$BUTLER" status "$ITCH_TARGET:$CHANNEL"
