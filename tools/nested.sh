#!/usr/bin/env bash
# Starts a nested KWin in a window of the current Plasma Wayland session, with its own
# D-Bus session, config folder and data folder (all under .nested/), so testing never
# touches the real session. Then installs and enables United Sets X in it.
#
#   tools/nested.sh            start (WIDTH, HEIGHT, SCALE env vars are honoured)
#   tools/nested.sh stop       stop it
#   tools/nested-run.sh CMD    run CMD inside it, e.g. tools/nested-run.sh kate
#   tools/reload.sh --nested   reinstall and restart the script inside it
#   tail -f .nested/kwin.log   its log (script console output included)
set -euo pipefail
source "$(dirname "$0")/common.sh"

# PID of the nested kwin_wayland, found by its command line (never trusted from a
# file: KWin starts its session apps through systemd, so a child's parent PID is the
# user's systemd, and killing that ends the whole desktop session).
nested_kwin_pid() {
    pgrep -u "$(id -u)" -x kwin_wayland -a | awk -v s="--socket $NESTED_SOCKET" 'index($0, s) { print $1; exit }'
}

if [[ "${1:-}" == "stop" ]]; then
    pid="$(nested_kwin_pid)"
    if [[ -n "$pid" ]]; then
        kill "$pid"
    else
        echo "no nested KWin running"
    fi
    rm -f "$NESTED_DIR/env"
    exit 0
fi

[[ -n "${WAYLAND_DISPLAY:-}" ]] || die "run this from a Plasma Wayland session"
[[ -z "$(nested_kwin_pid)" ]] || die "a nested KWin is already running (tools/nested.sh stop)"

mkdir -p "$NESTED_DIR/config" "$NESTED_DIR/data" "$NESTED_DIR/cache"
rm -f "$NESTED_DIR/env"
# Verbose script log in the nested session (written before KWin reads its config).
XDG_CONFIG_HOME="$NESTED_DIR/config" kwriteconfig6 --file kwinrc --group "Script-$SCRIPT_ID" --key Debug true
# Same colors, fonts and accent as the real session.
cp -f "$HOME/.config/kdeglobals" "$NESTED_DIR/config/" 2>/dev/null || true

# The first client KWin starts records the session's environment in .nested/env.
# (KWin takes its session apps without arguments, hence a script file.)
cat > "$NESTED_DIR/reporter.sh" <<'EOS'
#!/usr/bin/env bash
dir="$(dirname "$0")"
printf "DBUS_SESSION_BUS_ADDRESS=%q\nWAYLAND_DISPLAY=%q\nDISPLAY=%q\nXDG_CONFIG_HOME=%q\nXDG_DATA_HOME=%q\n" \
    "$DBUS_SESSION_BUS_ADDRESS" "$WAYLAND_DISPLAY" "$DISPLAY" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" > "$dir/env.tmp"
mv "$dir/env.tmp" "$dir/env"
EOS
chmod +x "$NESTED_DIR/reporter.sh"

# Themes, icons and cursors installed in ~/.local/share stay visible, but not the KWin
# scripts and effects installed in the real session (they would shadow the working copy).
rm -rf "$NESTED_DIR/userdata"
mkdir -p "$NESTED_DIR/userdata"
for entry in "$HOME/.local/share"/*; do
    case "$(basename "$entry")" in
        kwin|kwin-wayland) ;;
        *) ln -s "$entry" "$NESTED_DIR/userdata/" ;;
    esac
done

# Script messages and QML errors are logged.
XDG_CONFIG_HOME="$NESTED_DIR/config" XDG_DATA_HOME="$NESTED_DIR/data" XDG_CACHE_HOME="$NESTED_DIR/cache" \
QML_DISABLE_DISK_CACHE=1 \
XDG_DATA_DIRS="$NESTED_DIR/userdata:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
QT_LOGGING_RULES="kwin_scripting.debug=true;qml.debug=true;js.debug=true" \
    setsid dbus-run-session -- kwin_wayland \
        --socket "$NESTED_SOCKET" --xwayland --no-lockscreen \
        --width "${WIDTH:-1600}" --height "${HEIGHT:-900}" --scale "${SCALE:-1}" \
        "$NESTED_DIR/reporter.sh" \
    >"$NESTED_DIR/kwin.log" 2>&1 < /dev/null &

for _ in $(seq 50); do
    [[ -f "$NESTED_DIR/env" ]] && break
    sleep 0.2
done
[[ -f "$NESTED_DIR/env" ]] || die "nested KWin did not start, see $NESTED_DIR/kwin.log"

"$(dirname "$0")/install.sh" --nested
echo "Nested KWin is running. Try: tools/nested-run.sh kate   (or xterm for an XWayland window)"
