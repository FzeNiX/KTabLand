#!/usr/bin/env bash
# Installs (or upgrades) KTabLand and (re)starts it in KWin.
#   tools/install.sh            into the current Plasma session (~/.local/share/kwin/...)
#   tools/install.sh --nested   into the nested KWin started by tools/nested.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"
use_target "$@"

install_pkg() { # type dir
    kpackagetool6 --type "$1" --upgrade "$2" >/dev/null 2>&1 || kpackagetool6 --type "$1" --install "$2" >/dev/null
}

# --files-only: copy the packages and enable the script, without talking to KWin
# (used by nested.sh before the nested KWin starts).
if [[ " ${ARGS[*]} " == *" --files-only "* ]]; then
    for id in "${EFFECT_IDS[@]}"; do
        install_pkg KWin/Effect "$REPO_DIR/effects/$id"
    done
    install_pkg KWin/Script "$REPO_DIR/package"
    kwriteconfig6 --file kwinrc --group Plugins --key "${SCRIPT_ID}Enabled" true
    exit 0
fi

# Stop the running copy first: the script gives every hidden window back when it stops.
if [[ "$(kwin_dbus /Scripting org.kde.kwin.Scripting.isScriptLoaded "$SCRIPT_ID")" == "true" ]]; then
    kwin_dbus /Scripting org.kde.kwin.Scripting.unloadScript "$SCRIPT_ID" >/dev/null
fi
for id in "${EFFECT_IDS[@]}"; do
    kwin_dbus /Effects org.kde.kwin.Effects.unloadEffect "$id" >/dev/null 2>&1 || true
    install_pkg KWin/Effect "$REPO_DIR/effects/$id"
done
install_pkg KWin/Script "$REPO_DIR/package"

kwriteconfig6 --file kwinrc --group Plugins --key "${SCRIPT_ID}Enabled" true
kwin_dbus /Scripting org.kde.kwin.Scripting.start >/dev/null
if [[ "$(kwin_dbus /Scripting org.kde.kwin.Scripting.isScriptLoaded "$SCRIPT_ID")" == "true" ]]; then
    echo "KTabLand is installed and running ($TARGET)."
else
    die "installed, but KWin did not load the script; check the log (tools/logs.sh $*)"
fi
