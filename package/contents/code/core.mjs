// SPDX-License-Identifier: MIT
//
// Window groups ("sets") of United Sets X.
//
// A group shows only its active window. The other members stay at the same geometry,
// are made fully transparent, are kept directly below the active window
// (Workspace.constrain) and are taken out of the taskbar, Alt+Tab and the pager.
// Switching tabs shows the new window before hiding the old one, so nothing flickers.
//
// No QML here: main.qml passes the KWin objects and callbacks it needs ("host") and
// draws one tab bar per group from this model.

const DRAG_EDGE = 6; // px around a tab bar that still count as "on the bar"

function key(window) {
    return String(window.internalId);
}

function plainRect(r) {
    return { x: r.x, y: r.y, width: r.width, height: r.height };
}

function sameRect(a, b) {
    return Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5
        && Math.abs(a.width - b.width) < 0.5 && Math.abs(a.height - b.height) < 0.5;
}

function contains(r, p, margin = 0) {
    return p.x >= r.x - margin && p.x < r.x + r.width + margin
        && p.y >= r.y - margin && p.y < r.y + r.height + margin;
}

function intersects(a, b) {
    return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}

function union(a, b) {
    const x = Math.min(a.x, b.x);
    const y = Math.min(a.y, b.y);
    return {
        x, y,
        width: Math.max(a.x + a.width, b.x + b.width) - x,
        height: Math.max(a.y + a.height, b.y + b.height) - y,
    };
}

export class Manager {
    // host = {
    //   workspace            the KWin Workspace singleton
    //   clientArea(window)   work area of the window's screen (MaximizeArea)
    //   config()             { showTabBar, tabBarHeight, tabWidth }
    //   changed()            what the tab bars show may have changed (host coalesces calls)
    //   groupAdded(id), groupRemoved(id)
    //   dragStarted(), dragEnded()     a window move began / ended (host polls the modifier)
    //   highlight(rect | null)         show / hide the drop highlight
    //   later(fn)                      runs fn after the current KWin event
    //   openTabOptions(window, pos)    shows the tab name / color popup at pos
    //   log(message), debug(message)   debug() prints only with Debug=true in the config
    // }
    constructor(host) {
        this.host = host;
        this.ws = host.workspace;
        this.groups = [];
        this.membership = new Map(); // window key -> group
        this.hooks = new Map(); // window key -> { window, connections }
        this.nextGroupId = 1;
        this.drag = null; // { window, held, target }
        this.workspaceConnections = [];
    }

    // ---------------------------------------------------------------- lifecycle

    start() {
        this.restoreOrphans();
        for (const window of this.allWindows()) {
            this.watch(window);
        }
        this.connect(this.workspaceConnections, this.ws.windowAdded, (window) => this.watch(window));
        this.connect(this.workspaceConnections, this.ws.windowRemoved, (window) => this.windowGone(window));
        this.connect(this.workspaceConnections, this.ws.windowActivated, (window) => this.windowActivated(window));
        this.connect(this.workspaceConnections, this.ws.currentDesktopChanged, () => this.changed());
    }

    // Gives every window back as it was. Called when the script stops (disabled,
    // uninstalled, reinstalled, KWin quitting).
    stop() {
        for (const group of [...this.groups]) {
            this.dissolve(group);
        }
        for (const hook of this.hooks.values()) {
            this.disconnectAll(hook.connections);
        }
        this.hooks.clear();
        this.disconnectAll(this.workspaceConnections);
        this.host.highlight(null);
    }

    // A previous instance that could not clean up (crash, kill) may have left windows
    // transparent and out of the taskbar: show them again.
    restoreOrphans() {
        for (const window of this.allWindows()) {
            if (window.managed && window.normalWindow && window.opacity < 0.01
                && window.skipTaskbar && window.skipSwitcher) {
                this.host.log(`showing window left hidden by a previous run: ${window.caption}`);
                window.opacity = 1;
                window.skipTaskbar = false;
                window.skipSwitcher = false;
                window.skipPager = false;
            }
        }
    }

    // Declarative scripts have Workspace.windows (a QML list); JS scripts windowList().
    allWindows() {
        const list = typeof this.ws.windowList === "function" ? this.ws.windowList() : this.ws.windows;
        const result = [];
        for (let i = 0; i < list.length; i++) {
            result.push(list[i]);
        }
        return result;
    }

    connect(list, signal, handler) {
        signal.connect(handler);
        list.push({ signal, handler });
    }

    disconnectAll(list) {
        for (const c of list) {
            try {
                c.signal.disconnect(c.handler);
            } catch (e) {
                // The window is already gone.
            }
        }
        list.length = 0;
    }

    watch(window) {
        if (!window || !window.managed || this.isInternal(window) || this.hooks.has(key(window))) {
            return;
        }
        const connections = [];
        this.connect(connections, window.interactiveMoveResizeStarted, () => {
            this.leaveMaximizeOnMoveResize(window);
            if (window.move) {
                this.dragStarted(window);
            }
        });
        this.connect(connections, window.interactiveMoveResizeFinished, () => this.moveResizeFinished(window));
        this.connect(connections, window.frameGeometryChanged, () => this.geometryChanged(window));
        this.connect(connections, window.maximizedChanged, () => this.maximizedChanged(window));
        this.connect(connections, window.desktopsChanged, () => this.desktopsChanged(window));
        this.connect(connections, window.minimizedChanged, () => this.minimizedChanged(window));
        this.connect(connections, window.fullScreenChanged, () => this.changed());
        this.connect(connections, window.stackingOrderChanged, () => this.changed());
        this.connect(connections, window.closed, () => this.windowGone(window));
        this.hooks.set(key(window), { window, connections });
    }

    changed() {
        if (this.groups.length > 0) {
            this.host.changed();
        }
    }

    // ---------------------------------------------------------------- queries

    groupOf(window) {
        return window ? this.membership.get(key(window)) ?? null : null;
    }

    group(id) {
        return this.groups.find((g) => g.id === id) ?? null;
    }

    isTabbable(window) {
        return !!window && !window.deleted && window.managed && !this.isInternal(window) && window.normalWindow
            && !window.transient && !window.specialWindow && !window.popupWindow
            && window.moveable && !window.fullScreen;
    }

    // KWin's own windows (tab bars, highlight, OSDs) are "managed" too; they have no
    // process and no window class.
    isInternal(window) {
        return window.pid === -1 && !window.resourceClass;
    }

    isOnCurrentDesktop(window) {
        if (!window.onAllDesktops && !window.desktops.includes(this.ws.currentDesktop)) {
            return false;
        }
        const activities = window.activities;
        return activities.length === 0 || activities.includes(this.ws.currentActivity);
    }

    // Visible client window that can cover a tab bar.
    isCovering(window) {
        return window.managed && !this.isInternal(window) && !window.deleted && !window.minimized && !window.hidden
            && window.opacity > 0.01 && (window.normalWindow || window.dialog || window.utility)
            && this.isOnCurrentDesktop(window);
    }

    // Where the tab bar of `group` goes: above the active window when there is room,
    // otherwise (maximized, or at the top edge) over the top of the window, centered and
    // only as wide as the tabs. `frame` is passed by the bar so that its binding follows
    // the window's geometry.
    barRect(group, frame = group.active.frameGeometry) {
        const config = this.host.config();
        const height = config.tabBarHeight;
        const area = this.host.clientArea(group.active);
        // The bar overlaps the top of the window a little, hiding its rounded corners.
        const top = frame.y - height + (group.maximized ? 0 : config.overlap);
        if (top >= area.y - 0.5) {
            return { x: frame.x, y: top, width: frame.width, height, inside: false };
        }
        const width = Math.min(frame.width, group.windows.length * config.tabWidth + 8);
        return { x: frame.x + (frame.width - width) / 2, y: frame.y, width, height, inside: true };
    }

    // Recomputes which tab bars are shown; main.qml calls it before redrawing the bars,
    // outside of any QML binding (bindings must not read Workspace.stackingOrder).
    updateBars() {
        this.shownBars = new Map();
        for (const group of this.groups) {
            this.shownBars.set(group.id, this.barVisible(group));
        }
    }

    isBarShown(id) {
        return this.shownBars ? this.shownBars.get(id) === true : false;
    }

    barVisible(group) {
        const active = group.active;
        if (!this.host.config().showTabBar || !active || active.deleted || active.minimized
            || active.fullScreen || active.hidden || !this.isOnCurrentDesktop(active)) {
            this.host.debug(`bar ${group.id} hidden: minimized=${active.minimized} fullScreen=${active.fullScreen} hidden=${active.hidden} onCurrentDesktop=${this.isOnCurrentDesktop(active)}`);
            return false;
        }
        return !this.isBarCovered(group, this.barRect(group));
    }

    // Tab bars are KWin internal windows, which KWin always stacks above normal
    // windows, so a bar hides itself when another window overlaps it. The window being
    // dragged does not count, so that a bar stays visible as a drop target.
    isBarCovered(group, rect) {
        const draggedGroup = this.drag ? this.groupOf(this.drag.window) : null;
        const level = group.active.stackingOrder;
        for (const { window } of this.hooks.values()) {
            if (window.stackingOrder <= level) {
                continue;
            }
            if (this.drag && (window === this.drag.window || (draggedGroup && this.groupOf(window) === draggedGroup))) {
                continue;
            }
            if (this.groupOf(window) === group || !this.isCovering(window)) {
                continue;
            }
            if (intersects(window.frameGeometry, rect)) {
                this.host.debug(`bar ${group.id} covered by "${window.caption}" (${window.resourceClass}, pid ${window.pid})`);
                return true;
            }
        }
        return false;
    }

    // ---------------------------------------------------------------- grouping

    // Puts `window` (with its whole group, if it has one) into the group of `target`,
    // creating that group if needed. `window` becomes the visible tab.
    join(window, target) {
        if (!this.isTabbable(window) || !this.isTabbable(target) || window === target) {
            return false;
        }
        let group = this.groupOf(target);
        const from = this.groupOf(window);
        if (from && from === group) {
            return false;
        }
        if (!group) {
            group = {
                id: this.nextGroupId++,
                windows: [],
                active: target,
                saved: new Map(),
                constraints: [],
                maximized: false, // maximized by the script: tab bar on top, window below it
                normal: target.maximizeMode === 0 ? plainRect(target.frameGeometry) : null, // last unmaximized geometry
            };
            this.groups.push(group);
            this.addMember(group, target);
            this.host.groupAdded(group.id);
        }
        const incoming = from ? [...from.windows] : [window];
        const saved = new Map();
        if (from) {
            for (const w of incoming) {
                saved.set(key(w), from.saved.get(key(w)));
            }
            this.forget(from);
        }
        for (const w of incoming) {
            this.addMember(group, w, saved.get(key(w)));
        }
        this.activate(group, window);
        if (group.active.maximizeMode === 3 && !group.maximized) {
            this.maximizeGroup(group);
        }
        this.host.log(`group ${group.id}: ${group.windows.length} tabs`);
        return true;
    }

    addMember(group, window, saved) {
        group.windows.push(window);
        this.membership.set(key(window), group);
        group.saved.set(key(window), saved ?? {
            opacity: window.opacity,
            skipTaskbar: window.skipTaskbar,
            skipSwitcher: window.skipSwitcher,
            skipPager: window.skipPager,
        });
        if (window.tile) {
            // KWin tiles a window dropped with Shift held; the group decides the geometry.
            window.tile = null;
        }
        if (group.maximized) {
            this.removeBorder(window);
        } else {
            this.giveBorderBack(window);
        }
        if (window !== group.active) {
            this.matchGroup(window, group.active);
            this.hide(window);
        }
    }

    // Shows `window` as the current tab of its group.
    activate(group, window) {
        const previous = group.active;
        this.host.debug(`switch group ${group.id} to "${window.caption}"`);
        if (previous !== window) {
            this.matchGroup(window, previous);
            group.active = window;
            this.show(group, window); // show the new tab first...
        }
        this.ws.activeWindow = window;
        if (previous !== window && previous && group.windows.includes(previous)) {
            this.hide(previous); // ...then hide the old one
        }
        this.restack(group);
        this.changed();
    }

    cycle(step) {
        const group = this.groupOf(this.ws.activeWindow);
        if (!group) {
            return;
        }
        const count = group.windows.length;
        const index = group.windows.indexOf(group.active);
        this.activate(group, group.windows[(index + step + count) % count]);
    }

    reorder(group, window, index) {
        const from = group.windows.indexOf(window);
        if (from < 0) {
            return;
        }
        index = Math.max(0, Math.min(group.windows.length - 1, index));
        if (index !== from) {
            group.windows.splice(from, 1);
            group.windows.splice(index, 0, window);
            this.changed();
        }
    }

    // Takes `window` out of its group and gives it back as it was; with `position`
    // (a tab dropped outside any bar), the window is moved under the cursor.
    detach(window, position) {
        const group = this.groupOf(window);
        if (!group) {
            return;
        }
        const size = group.maximized ? (group.restore ?? this.defaultRestore(group)) : null;
        this.removeMember(group, window, true);
        const frame = size ?? window.frameGeometry;
        // Under the cursor for a tab dragged out, slightly offset for the shortcut so
        // that the released window does not exactly cover the group.
        window.frameGeometry = {
            x: Math.round(position ? position.x - Math.min(frame.width / 2, 120) : frame.x + 40),
            y: Math.round(position ? position.y - 12 : frame.y + 40),
            width: frame.width,
            height: frame.height,
        };
        this.ws.activeWindow = window;
    }

    moveToGroup(window, group) {
        const from = this.groupOf(window);
        if (!from || from === group) {
            return;
        }
        const saved = from.saved.get(key(window));
        this.removeMember(from, window, false);
        this.addMember(group, window, saved);
        this.activate(group, window);
    }

    removeMember(group, window, restore) {
        const index = group.windows.indexOf(window);
        if (index < 0) {
            return;
        }
        const saved = group.saved.get(key(window));
        this.unconstrainAll(group);
        group.windows.splice(index, 1);
        group.saved.delete(key(window));
        this.membership.delete(key(window));
        if (group.active === window && group.windows.length > 0) {
            const next = group.windows[Math.min(index, group.windows.length - 1)];
            this.matchGroup(next, window);
            group.active = next;
            this.show(group, next);
            if (!restore) {
                this.ws.activeWindow = next;
            }
        }
        if (restore) {
            this.restoreWindow(window, saved);
            this.giveBorderBack(window);
            this.tabInfos?.delete(key(window));
        }
        if (group.windows.length <= 1) {
            this.dissolve(group);
        } else {
            this.restack(group);
            this.changed();
        }
    }

    // Ends a group and gives every member back as it was.
    dissolve(group) {
        this.unconstrainAll(group);
        for (const window of group.windows) {
            this.tabInfos?.delete(key(window));
            if (!window.deleted) {
                this.restoreWindow(window, group.saved.get(key(window)));
                this.giveBorderBack(window);
                if (group.maximized && window.maximizable) {
                    // Without its tab bar the window is maximized the usual way.
                    window.setMaximize(true, true);
                }
            }
        }
        this.forget(group);
        this.host.log(`group ${group.id} dissolved`);
    }

    // Drops the group record without touching its windows.
    forget(group) {
        this.unconstrainAll(group);
        for (const window of group.windows) {
            this.membership.delete(key(window));
        }
        this.groups.splice(this.groups.indexOf(group), 1);
        this.host.groupRemoved(group.id);
        this.host.changed();
    }

    // ---------------------------------------------------------------- hiding

    hide(window) {
        window.opacity = 0;
        window.skipTaskbar = true;
        window.skipSwitcher = true;
        window.skipPager = true;
    }

    show(group, window) {
        const saved = group.saved.get(key(window));
        if (window.minimized) {
            window.minimized = false;
        }
        this.restoreWindow(window, saved);
    }

    restoreWindow(window, saved) {
        saved = saved ?? { opacity: 1, skipTaskbar: false, skipSwitcher: false, skipPager: false };
        window.opacity = saved.opacity > 0.01 ? saved.opacity : 1;
        window.skipTaskbar = saved.skipTaskbar;
        window.skipSwitcher = saved.skipSwitcher;
        window.skipPager = saved.skipPager;
    }

    // Keeps the hidden members directly below the active window, so they are raised
    // with it and never end up above another window.
    restack(group) {
        this.unconstrainAll(group);
        if (typeof this.ws.constrain !== "function") {
            return; // KWin < 6.5
        }
        for (const window of group.windows) {
            if (window !== group.active) {
                this.ws.constrain(window, group.active);
                group.constraints.push([window, group.active]);
            }
        }
    }

    unconstrainAll(group) {
        if (typeof this.ws.unconstrain === "function") {
            for (const [below, above] of group.constraints) {
                if (!below.deleted && !above.deleted) {
                    this.ws.unconstrain(below, above);
                }
            }
        }
        group.constraints = [];
    }

    // Gives `window` the geometry, maximize state and desktops of `reference`.
    matchGroup(window, reference) {
        if (!reference || reference === window || reference.deleted) {
            return;
        }
        if (window.maximizeMode !== reference.maximizeMode) {
            const mode = reference.maximizeMode;
            window.setMaximize((mode & 1) !== 0, (mode & 2) !== 0);
        }
        if (!sameRect(window.frameGeometry, reference.frameGeometry)) {
            window.frameGeometry = plainRect(reference.frameGeometry);
        }
        if (window.onAllDesktops !== reference.onAllDesktops) {
            window.onAllDesktops = reference.onAllDesktops;
        }
        if (!reference.onAllDesktops && String(window.desktops) !== String(reference.desktops)) {
            window.desktops = reference.desktops;
        }
    }

    syncMembers(group) {
        for (const window of group.windows) {
            if (window !== group.active) {
                this.matchGroup(window, group.active);
            }
        }
    }

    // ---------------------------------------------------------------- window events

    geometryChanged(window) {
        const group = this.groupOf(window);
        if (group && window === group.active && group.maximized && !this.applyingMaximize
            && !window.move && !window.resize && window.frameGeometry.y < this.maximizedRect(group).y - 1) {
            // KWin put the window back over the tab bar (its tile was laid out again, a
            // screen or panel changed): move it below the bar again.
            this.host.later(() => {
                if (this.groups.includes(group) && group.maximized) {
                    this.applyMaximized(group);
                }
            });
        }
        if (group && window === group.active && !group.maximized && window.maximizeMode === 0
            && !this.applyingMaximize) {
            group.normal = plainRect(window.frameGeometry);
        }
        if (group && window === group.active && !window.resize) {
            // Moving is cheap, so hidden tabs follow every step; resizing makes the
            // apps redraw, so they catch up when the resize ends.
            this.syncMembers(group);
        }
        this.changed();
    }

    maximizedChanged(window) {
        const group = this.groupOf(window);
        if (group) {
            this.host.debug(`"${window.caption}" maximizeMode=${window.maximizeMode} (visible tab: ${window === group.active}, group maximized: ${group.maximized}, applying: ${!!this.applyingMaximize})`);
        }
        if (group && window === group.active && window.maximizeMode === 3 && !this.applyingMaximize) {
            // KWin maximized the visible tab (its button, a double click, a drag to the top
            // edge, a shortcut). A maximized group is not maximized for KWin (that would
            // cover the tab bar), so this means "maximize the group", or "restore" when it
            // already is. Done once KWin has finished (it ignores changes made meanwhile).
            const restore = group.maximized;
            this.host.later(() => {
                if (!this.groups.includes(group) || group.active !== window) {
                    return;
                }
                if (restore) {
                    this.unmaximizeGroup(group);
                } else {
                    this.maximizeGroup(group);
                }
            });
            return;
        }
        if (group && window === group.active) {
            this.syncMembers(group);
        }
        this.changed();
    }

    // ---------------------------------------------------------------- maximize

    // A maximized group fills the work area: tab bar at the top, the visible tab below it.
    // KWin does not see the windows as maximized (it would cover the tab bar), so the
    // script removes the frame KWin draws around them (title bar, borders, rounded
    // corners); apps that draw their own title bar keep it.
    maximizeGroup(group) {
        if (!group.maximized) {
            // A "normal" geometry that already fills the screen (the window was maximized
            // before it joined the group) would restore to the same size.
            const area = this.host.clientArea(group.active);
            const normal = group.normal;
            const fills = normal && normal.width * normal.height > 0.9 * area.width * area.height;
            group.restore = normal && !fills ? normal : this.defaultRestore(group);
        }
        group.maximized = true;
        this.applyMaximized(group);
    }

    unmaximizeGroup(group) {
        if (!group.maximized) {
            return;
        }
        group.maximized = false;
        this.applyingMaximize = true;
        for (const window of group.windows) {
            this.giveBorderBack(window);
            if (window.maximizeMode !== 0) {
                // Requested by a KWin maximize, which left the window marked maximized.
                window.setMaximize(false, false);
            }
        }
        group.active.frameGeometry = group.restore ?? this.defaultRestore(group);
        this.applyingMaximize = false;
        group.normal = plainRect(group.active.frameGeometry);
        this.syncMembers(group);
        this.changed();
    }

    maximizedRect(group) {
        const area = this.host.clientArea(group.active);
        const height = this.host.config().tabBarHeight;
        return { x: area.x, y: area.y + height, width: area.width, height: area.height - height };
    }

    applyMaximized(group) {
        const active = group.active;
        const rect = this.maximizedRect(group);
        this.host.debug(`group ${group.id} maximized into ${JSON.stringify(rect)}`);
        this.applyingMaximize = true;
        if (active.maximizeMode !== 0) {
            active.setMaximize(false, false);
        }
        for (const window of group.windows) {
            this.removeBorder(window);
        }
        active.frameGeometry = rect;
        this.applyingMaximize = false;
        this.syncMembers(group);
        this.changed();
    }

    defaultRestore(group) {
        const area = this.host.clientArea(group.active);
        const width = Math.round(area.width * 0.6);
        const height = Math.round(area.height * 0.7);
        return { x: area.x + (area.width - width) / 2, y: area.y + (area.height - height) / 2, width, height };
    }

    // While its group is maximized, a window must look maximized although KWin does not
    // see it so: the frame KWin draws (server-side decoration) is removed, and the window
    // is put in the screen's root tile, so that apps drawing their own frame (Chrome,
    // GTK...) are told they are tiled on all edges and drop their rounded corners,
    // shadows and resize borders.
    removeBorder(window) {
        if (!this.borderless) {
            this.borderless = new Set();
            this.tiled = new Set();
        }
        if (!window.noBorder) {
            this.borderless.add(key(window));
            window.noBorder = true;
        }
        if (!this.tiled.has(key(window)) && typeof this.ws.rootTile === "function") {
            const tile = this.ws.rootTile(window.output, this.ws.currentDesktop);
            if (tile && tile.manage(window)) {
                this.tiled.add(key(window));
            }
        }
    }

    giveBorderBack(window) {
        if (this.borderless?.delete(key(window)) && !window.deleted) {
            window.noBorder = false;
        }
        if (this.tiled?.delete(key(window)) && !window.deleted && window.tile) {
            window.tile.unmanage(window);
        }
    }

    // Whether the visible tab has rounded top corners under the bar (for CornerEars).
    hasRoundedTop(group) {
        const id = key(group.active);
        return !(group.maximized && (this.borderless?.has(id) || this.tiled?.has(id)));
    }

    // Moving a maximized group restores its size under the cursor (as KWin does for a
    // maximized window); resizing it just ends the maximized state.
    leaveMaximizeOnMoveResize(window) {
        const group = this.groupOf(window);
        if (!group || window !== group.active || !group.maximized) {
            return;
        }
        group.maximized = false;
        this.applyingMaximize = true;
        for (const member of group.windows) {
            this.giveBorderBack(member);
        }
        if (window.move) {
            const restore = group.restore ?? this.defaultRestore(group);
            const frame = window.frameGeometry;
            const cursor = this.ws.cursorPos;
            const ratio = frame.width > 0 ? (cursor.x - frame.x) / frame.width : 0.5;
            window.frameGeometry = {
                x: Math.round(cursor.x - restore.width * ratio),
                y: frame.y,
                width: restore.width,
                height: restore.height,
            };
        }
        this.applyingMaximize = false;
        this.changed();
    }

    // Minimizing or restoring the visible tab does it for the whole group. The hidden
    // tabs are minimized too, so that KWin does not activate one of them next.
    minimizedChanged(window) {
        const group = this.groupOf(window);
        if (group) {
            this.host.debug(`"${window.caption}" minimized=${window.minimized} (visible tab: ${window === group.active})`);
        }
        if (group && window === group.active) {
            for (const member of group.windows) {
                if (member !== window && member.minimized !== window.minimized) {
                    member.minimized = window.minimized;
                }
            }
        }
        this.changed();
    }

    desktopsChanged(window) {
        const group = this.groupOf(window);
        if (group && window === group.active) {
            this.syncMembers(group);
        }
        this.changed();
    }

    windowActivated(window) {
        const group = this.groupOf(window);
        if (group) {
            this.host.debug(`activated "${window.caption}" (group ${group.id}, visible tab "${group.active.caption}" minimized=${group.active.minimized})`);
        }
        if (group && group.active !== window && group.active.minimized) {
            // The visible tab was just minimized and KWin gives the focus to the next
            // window, a hidden tab of the same group: minimize the rest of the group
            // instead of showing it. KWin then activates a window outside the group.
            this.minimizedChanged(group.active);
            return;
        }
        if (group && group.active !== window) {
            // Something activated a hidden tab (the app itself, a notification...).
            this.activate(group, window);
        }
        this.changed();
    }

    windowGone(window) {
        this.tabInfos?.delete(key(window));
        this.borderless?.delete(key(window));
        this.tiled?.delete(key(window));
        const hook = this.hooks.get(key(window));
        if (hook) {
            this.disconnectAll(hook.connections);
            this.hooks.delete(key(window));
        }
        if (this.drag && this.drag.window === window) {
            this.endDrag();
        }
        const group = this.groupOf(window);
        if (group) {
            this.removeMember(group, window, false);
        }
    }

    moveResizeFinished(window) {
        if (this.drag && this.drag.window === window) {
            const target = this.drag.held ? this.dropTarget(this.ws.cursorPos, window) : null;
            this.endDrag();
            if (target) {
                this.join(window, target.window);
                return;
            }
        }
        const group = this.groupOf(window);
        if (group && window === group.active) {
            this.syncMembers(group);
        }
        this.changed();
    }

    // ---------------------------------------------------------------- drag to group

    dragStarted(window) {
        this.drag = { window, held: false, target: null };
        this.host.dragStarted();
    }

    // Called by the host while a window is being moved, with whether the grouping
    // modifier is held.
    dragStep(held) {
        if (!this.drag) {
            return;
        }
        this.drag.held = held;
        this.drag.target = held ? this.dropTarget(this.ws.cursorPos, this.drag.window) : null;
        this.host.highlight(this.drag.target ? this.drag.target.rect : null);
    }

    endDrag() {
        this.drag = null;
        this.host.dragEnded();
        this.host.highlight(null);
        this.changed();
    }

    // The window or group that `dragged` would join if dropped at `position`.
    dropTarget(position, dragged) {
        if (!this.isTabbable(dragged)) {
            return null;
        }
        const from = this.groupOf(dragged);
        const bar = this.groupWithBarAt(position, from);
        if (bar) {
            return { window: bar.active, rect: union(this.barRect(bar), bar.active.frameGeometry) };
        }
        for (const window of this.ws.windowAt(position, 64)) {
            if (window === dragged || !window.managed || this.isInternal(window) || window.opacity < 0.01
                || (from && this.groupOf(window) === from)) {
                continue;
            }
            if (!this.isTabbable(window)) {
                return null; // the topmost window under the cursor cannot take tabs
            }
            const group = this.groupOf(window);
            if (group) {
                return { window, rect: this.barVisible(group) ? union(this.barRect(group), window.frameGeometry) : plainRect(window.frameGeometry) };
            }
            return { window, rect: plainRect(window.frameGeometry) };
        }
        return null;
    }

    groupWithBarAt(position, except) {
        for (const group of this.groups) {
            if (group !== except && this.barVisible(group) && contains(this.barRect(group), position, DRAG_EDGE)) {
                return group;
            }
        }
        return null;
    }

    // ---------------------------------------------------------------- tab bar actions

    // A tab is being dragged outside its own bar: highlight the bar it would move to.
    tabDragged(group, position) {
        const target = this.groupWithBarAt(position, group);
        this.host.highlight(target ? this.barRect(target) : null);
    }

    // A tab was dropped outside its own bar.
    tabDropped(group, window, position) {
        this.host.highlight(null);
        const target = this.groupWithBarAt(position, group);
        if (target) {
            this.moveToGroup(window, target);
        } else {
            this.detach(window, position);
        }
    }

    // The empty part of a tab bar is being dragged: start KWin's own interactive move
    // of the visible tab, anchored at the cursor, as if its title bar was dragged.
    moveGroup(group) {
        const active = group.active;
        if (active.move || active.resize) {
            return;
        }
        if (this.ws.activeWindow !== active) {
            this.ws.activeWindow = active;
        }
        this.ws.slotWindowMove();
    }

    minimizeGroup(group) {
        if (group.active.minimizable) {
            group.active.minimized = true;
        }
    }

    toggleMaximize(group) {
        if (!group.active.maximizable) {
            return;
        }
        if (group.maximized) {
            this.unmaximizeGroup(group);
        } else {
            this.maximizeGroup(group);
        }
    }

    isMaximized(group) {
        return group.maximized;
    }

    // ---------------------------------------------------------------- tab names and colors

    // Name and color given to a tab by the user (kept while the window is grouped).
    tabInfo(window) {
        return this.tabInfos?.get(key(window)) ?? { name: "", color: "" };
    }

    setTabInfo(window, name, color) {
        if (!this.tabInfos) {
            this.tabInfos = new Map();
        }
        if (!name && !color) {
            this.tabInfos.delete(key(window));
        } else {
            this.tabInfos.set(key(window), { name, color });
        }
        this.changed();
    }

    // `position`: global point under the tab; by default under the group's tab bar.
    openTabOptions(window, position, parentWindow) {
        const group = this.groupOf(window);
        if (!position && group) {
            const bar = this.barRect(group);
            position = { x: bar.x, y: bar.y + bar.height };
        }
        this.host.openTabOptions(window, position ?? this.ws.cursorPos, parentWindow);
    }

    tabLabel(window) {
        return this.tabInfo(window).name || window.caption;
    }

    closeGroup(group) {
        for (const window of [...group.windows]) {
            window.closeWindow();
        }
    }

    closeTab(window) {
        window.closeWindow();
    }

    // Debug shortcut: prints every group.
    dump() {
        this.host.log(`${this.groups.length} groups, active window "${this.ws.activeWindow ? this.ws.activeWindow.caption : ""}"`);
        for (const group of this.groups) {
            this.host.log(`group ${group.id}: maximized=${group.maximized} bar=${JSON.stringify(this.barRect(group))} shown=${this.isBarShown(group.id)}`);
            for (const w of group.windows) {
                this.host.log(`  ${w === group.active ? "*" : " "} "${w.caption}" frame=${JSON.stringify(plainRect(w.frameGeometry))} maximizeMode=${w.maximizeMode} minimized=${w.minimized} opacity=${w.opacity}`);
            }
        }
    }

    // Shortcut: group the active window with the window right under it.
    groupActiveWithBelow() {
        const active = this.ws.activeWindow;
        if (!this.isTabbable(active)) {
            return;
        }
        const center = { x: active.x + active.width / 2, y: active.y + active.height / 2 };
        const from = this.groupOf(active);
        for (const window of this.ws.windowAt(center, 64)) {
            if (window !== active && window.managed && !this.isInternal(window) && window.opacity > 0.01
                && !(from && this.groupOf(window) === from) && this.isTabbable(window)) {
                this.join(active, window);
                return;
            }
        }
    }

    // Shortcut: release the active tab from its group.
    detachActive() {
        const active = this.ws.activeWindow;
        if (this.groupOf(active)) {
            this.detach(active, null);
        }
    }
}
