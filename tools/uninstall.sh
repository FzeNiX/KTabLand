#!/usr/bin/env bash
# Stops KTabLand (every hidden window is shown again), then removes it.
#   tools/uninstall.sh [--nested]
set -euo pipefail
source "$(dirname "$0")/common.sh"
use_target "$@"

kwriteconfig6 --file kwinrc --group Plugins --key "${SCRIPT_ID}Enabled" --delete
kwin_dbus /Scripting org.kde.kwin.Scripting.unloadScript "$SCRIPT_ID" >/dev/null 2>&1 || true
for id in "${EFFECT_IDS[@]}"; do
    kwin_dbus /Effects org.kde.kwin.Effects.unloadEffect "$id" >/dev/null 2>&1 || true
    kpackagetool6 --type KWin/Effect --remove "$id" >/dev/null 2>&1 || true
done
kpackagetool6 --type KWin/Script --remove "$SCRIPT_ID" >/dev/null 2>&1 || true
kwin_dbus /KWin org.kde.KWin.reconfigure >/dev/null
echo "KTabLand is removed ($TARGET)."
