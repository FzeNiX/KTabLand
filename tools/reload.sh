#!/usr/bin/env bash
# Reinstalls the working copy and restarts the script.
#   tools/reload.sh            real session
#   tools/reload.sh --nested   nested KWin: restarted too, because KWin's QML engine
#                              caches the script's files by path until KWin restarts
set -euo pipefail
dir="$(dirname "$0")"
if [[ " $* " == *" --nested "* ]]; then
    "$dir/nested.sh" stop
    sleep 1
    exec "$dir/nested.sh"
fi
exec "$dir/install.sh" "$@"
