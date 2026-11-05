#!/usr/bin/env bash
# Runs a command inside the nested KWin started by tools/nested.sh, e.g.:
#   tools/nested-run.sh kate &
#   tools/nested-run.sh xterm &                     (XWayland window)
#   tools/nested-run.sh qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadedEffects
set -euo pipefail
source "$(dirname "$0")/common.sh"
use_target --nested "$@"
[[ ${#ARGS[@]} -gt 0 ]] || die "usage: tools/nested-run.sh COMMAND [ARGS...]"
exec "${ARGS[@]}"
