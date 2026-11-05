# Architecture

On Wayland only the compositor can move, resize, hide or watch the windows of other applications, so
United Sets X runs inside KWin as a **declarative KWin script** (QML + JavaScript, stable public API, no
C++ build, no dependency on KWin's internal ABI).

```
package/                     KWin/Script "unitedsetsx"
  contents/code/core.mjs     group model and window management (no QML)
  contents/ui/main.qml       wiring: KWin signals, shortcuts, D-Bus, one TabBar per group
  contents/ui/TabBar.qml     tab bar (KWin internal window placed above the group)
  contents/ui/DropHighlight.qml
  contents/config/main.xml + contents/ui/config.ui   settings page (KWin Scripts KCM)
effects/
  unitedsetsx_modwatch       scripted effect: reports held modifier keys
  unitedsetsx_mod_*          empty "flag" effects
```

## Hiding tabs

A group shows only its active window. Every other member:

- keeps the group's geometry, maximize state and desktops (`frameGeometry`, `setMaximize`, `desktops`);
- is fully transparent (`opacity = 0`), not minimized: no minimize animation, and the app does not see a
  state change;
- has `skipTaskbar`, `skipSwitcher` and `skipPager` set, so the group is one entry in the taskbar, Alt+Tab
  and the pager;
- is kept directly below the active window with `Workspace.constrain()` (KWin 6.5+), so it is raised with
  it and never ends up above another window.

Switching tabs shows the new window, activates it, and only then hides the old one, all in the same event
loop pass: there is no frame without a visible window.

The original `opacity` / `skip*` values are saved per window and restored when a window leaves its group,
when a group ends and when the script stops (`Component.onDestruction`). At start, windows left transparent
and out of the taskbar by a previous instance (crash, kill) are shown again.

## Modifier key while dragging

KWin scripts cannot read the keyboard. Scripted effects can (`effects.mouseChanged` carries the keyboard
modifiers) but cannot talk to scripts. So:

1. When a window move starts, the script loads the `unitedsetsx_modwatch` effect over D-Bus
   (`org.kde.kwin.Effects.loadEffect`, a no-op when already loaded).
2. The effect loads `unitedsetsx_mod_<key>` while that modifier is held and unloads it on release.
3. During the move the script polls `org.kde.kwin.Effects.isEffectLoaded("unitedsetsx_mod_<key>")` every
   40 ms and computes the drop target under the cursor (`Workspace.windowAt`).

All these effects are marked `X-KWin-Internal` (not listed in Desktop Effects) and are never enabled in
the config: they only live while loaded by the script.

## Tab bars

Each tab bar is a QML `Window` created by the script, which KWin turns into an internal window. KWin puts
internal windows in its overlay layer (above normal windows, `Window::belongsToLayer`), so a bar hides
itself while another visible window overlaps it (`Manager.isBarCovered`). Internal windows never take
keyboard focus, so clicking a tab does not steal focus from the app.
