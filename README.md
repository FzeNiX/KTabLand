# United Sets X for KDE Plasma

**Group any windows into tabs on KDE Plasma 6 — hold <kbd>Ctrl</kbd> and drag one window onto another.**

The KDE Plasma counterpart of [United Sets X](https://github.com/FzeNiX/UnitedSetsX) for Windows. It is a
KWin script, so it works on Wayland and with XWayland apps, for any application (also the ones that draw
their own title bar, like Chrome, Firefox or GTK apps).

> Status: early MVP (0.1). Tested on Kubuntu 26.04, Plasma / KWin 6.6.6, Qt 6.10.

## Features (MVP)

- **Drag to group**: hold <kbd>Ctrl</kbd> (or Shift / Alt / Meta, see the settings) while dragging a window by
  its title bar and drop it on another window: both become tabs of one group. Drop it on a tab bar to add a
  tab. A highlight shows where the window will go.
- **Tab bar** in the Breeze style, following your color scheme, accent color and light / dark theme: click a
  tab to switch, <kbd>✕</kbd> or middle click to close, drag to reorder, drag out to release the window,
  drag onto another group's tab bar to move it there.
- **One window per group**: the tab bar is the group's title bar (drag its free part to move the group,
  double click to maximize, minimize / maximize / close-all buttons). Moving, resizing, minimizing,
  maximizing or changing the desktop of the visible tab applies to the whole group. Hidden tabs are out of
  the taskbar, Alt+Tab and the pager.
- **Maximized groups** keep their own full-width tab bar at the top of the screen, with the app below it
  (its own title bar and tabs, e.g. Chrome's, stay visible), like Groupy and United Sets X on Windows.
- **Shortcuts** (System Settings › Keyboard › Shortcuts › KWin): next / previous tab (<kbd>Meta</kbd>+<kbd>`</kbd> /
  <kbd>Meta</kbd>+<kbd>~</kbd>), group the active window with the window under it, release the active tab.
- **Safe**: when the script is disabled, removed or reinstalled, every hidden window is shown again; windows
  left hidden by a crash are shown again on the next start.

Why Ctrl by default: in Plasma 6, dragging a window with Shift held already snaps it into your custom tile
layout. Shift can still be chosen; then KWin's tile preview shows too.

## Install

```bash
git clone https://github.com/FzeNiX/UnitedSetsX-KDE.git
cd UnitedSetsX-KDE
tools/install.sh
```

Settings: System Settings › Window Management › KWin Scripts › United Sets X › configure.
Remove with `tools/uninstall.sh` (every grouped window is given back first).

## Known limitations

- The tab bar is a KWin internal window, and KWin always stacks those above normal windows, so a tab bar
  hides itself while another window overlaps it.
- When there is no room above a window that is not maximized (at the very top of the screen), the tab bar
  sits over the top of the window, centered.
- Updating the script's code in a running session takes effect after logging out and in again (KWin caches
  the QML files of scripts).

## How it works

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Development and testing in a nested KWin:
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## License

MIT, see [LICENSE](LICENSE).
