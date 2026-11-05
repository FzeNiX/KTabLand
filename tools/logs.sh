#!/usr/bin/env bash
# Follows KWin's log, keeping the lines of United Sets X and QML/JS errors.
#   tools/logs.sh             real session (journalctl, unit plasma-kwin_wayland.service)
#   tools/logs.sh --nested    nested KWin (.nested/kwin.log)
#   tools/logs.sh --all       every KWin line, unfiltered
set -euo pipefail
source "$(dirname "$0")/common.sh"
filter='unitedsets|\.qml|\.mjs|\.js:|ReferenceError|TypeError|scripting'
grep_args=(-E -i --line-buffered "$filter")
[[ " $* " == *" --all "* ]] && grep_args=(--line-buffered '')
if [[ " $* " == *" --nested "* ]]; then
    tail -n 200 -F "$NESTED_DIR/kwin.log" | grep "${grep_args[@]}"
else
    journalctl --user -u plasma-kwin_wayland.service -f -n 200 -o cat | grep "${grep_args[@]}"
fi
