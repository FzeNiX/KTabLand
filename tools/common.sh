# Shared settings for the tools/ scripts. Source it, don't run it.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_ID="unitedsetsx"
EFFECT_IDS=(unitedsetsx_modwatch unitedsetsx_mod_shift unitedsetsx_mod_ctrl unitedsetsx_mod_alt unitedsetsx_mod_meta)

# Nested KWin sandbox: its own config and data folders, its own D-Bus session.
NESTED_DIR="$REPO_DIR/.nested"
NESTED_SOCKET="wayland-unitedsetsx"

QDBUS="$(command -v qdbus6 || command -v qdbus)"

die() { echo "error: $*" >&2; exit 1; }

# Switches the current shell to the nested session (bus, Wayland and X11 display,
# XDG folders) when --nested was given. Call: use_target "$@"; then use $ARGS.
use_target() {
    ARGS=()
    TARGET="session"
    for a in "$@"; do
        if [[ "$a" == "--nested" ]]; then TARGET="nested"; else ARGS+=("$a"); fi
    done
    if [[ "$TARGET" == "nested" ]]; then
        [[ -f "$NESTED_DIR/env" ]] || die "no nested KWin running; start it with tools/nested.sh"
        # shellcheck disable=SC1091
        source "$NESTED_DIR/env"
        export DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY DISPLAY XDG_CONFIG_HOME XDG_DATA_HOME
        "$QDBUS" org.kde.KWin /KWin >/dev/null 2>&1 || die "nested KWin is not answering on its D-Bus (stale $NESTED_DIR/env?)"
    fi
}

kwin_dbus() { "$QDBUS" org.kde.KWin "$@"; }
