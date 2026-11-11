// SPDX-License-Identifier: MIT
import QtQuick
import QtQml
import org.kde.kwin
import "../code/core.mjs" as Core

Item {
    id: root

    // Bumped whenever the tab bars may need to change; bars re-read the model then.
    property int revision: 0
    property var manager: null
    property var config: readSettings()

    // Flag effects loaded by the ktabland_modwatch effect while a modifier is held,
    // indexed like the GroupModifier setting.
    readonly property var modifierFlags: ["ktabland_mod_shift", "ktabland_mod_ctrl", "ktabland_mod_alt", "ktabland_mod_meta"]

    function readSettings() {
        return {
            modifier: Number(KWin.readConfig("GroupModifier", 1)),
            showTabBar: Boolean(KWin.readConfig("ShowTabBar", true)),
            tabBarHeight: Number(KWin.readConfig("TabBarHeight", 32)),
            tabWidth: Number(KWin.readConfig("TabWidth", 220)),
            // 0 opaque (color scheme), 1 translucent (Plasma theme, blurred)
            barStyle: Number(KWin.readConfig("BarStyle", 0)),
            // How far the bar covers the top of the window, hiding its rounded corners.
            overlap: Number(KWin.readConfig("CornerOverlap", 0)),
            // Radius of the window's rounded top corners, which the bar's color wraps around.
            cornerFill: Number(KWin.readConfig("CornerFill", 8)),
            debug: Boolean(KWin.readConfig("Debug", false)),
        };
    }

    function bump() {
        if (manager) {
            manager.updateBars();
        }
        revision++;
    }

    function log(message) {
        console.info("KTabLand:", message);
    }

    ListModel {
        id: groupModel
    }

    // The tab bar window of a group (to attach popups to it).
    function barWindow(groupId) {
        const bars = root.config.barStyle === 1 ? translucentBars : solidBars;
        for (let i = 0; i < bars.count; i++) {
            const bar = bars.objectAt(i);
            if (bar && bar.groupId === groupId) {
                return bar;
            }
        }
        return null;
    }

    Instantiator {
        id: solidBars
        model: groupModel
        active: root.config.barStyle !== 1
        delegate: SolidBar {
            required property int gid
            groupId: gid
            manager: root.manager
            revision: root.revision
            config: root.config
        }
    }

    Instantiator {
        id: translucentBars
        model: groupModel
        active: root.config.barStyle === 1
        delegate: TranslucentBar {
            required property int gid
            groupId: gid
            manager: root.manager
            revision: root.revision
            config: root.config
        }
    }

    Instantiator {
        id: tabOptionsHolder
        model: 1
        delegate: TabOptions {
            manager: root.manager
        }
    }
    readonly property var tabOptions: tabOptionsHolder.object

    // Windows must not be children of an Item: Qt only shows such a window while the
    // Item's own window is visible, and a script has none. An Instantiator is their parent.
    Instantiator {
        id: highlightHolder
        model: 1
        delegate: DropHighlight {}
    }
    readonly property var highlight: highlightHolder.object

    DBusCall {
        id: loadModifierWatcher
        service: "org.kde.KWin"
        path: "/Effects"
        dbusInterface: "org.kde.kwin.Effects"
        method: "loadEffect"
        arguments: ["ktabland_modwatch"]
    }

    DBusCall {
        id: modifierQuery
        service: "org.kde.KWin"
        path: "/Effects"
        dbusInterface: "org.kde.kwin.Effects"
        method: "isEffectLoaded"
        arguments: [root.modifierFlags[root.config.modifier] ?? root.modifierFlags[1]]
        onFinished: (returnValue) => {
            if (root.manager) {
                root.manager.dragStep(returnValue[0] === true);
            }
        }
    }

    // While a window is being moved: is the grouping modifier held, and where would it drop?
    Timer {
        id: dragPoll
        interval: 40
        repeat: true
        triggeredOnStart: true
        onTriggered: modifierQuery.call()
    }

    ShortcutHandler {
        name: "KTabLand Next Tab"
        text: "KTabLand: Next tab"
        sequence: "Meta+`"
        onActivated: root.manager.cycle(1)
    }

    ShortcutHandler {
        name: "KTabLand Previous Tab"
        text: "KTabLand: Previous tab"
        sequence: "Meta+~"
        onActivated: root.manager.cycle(-1)
    }

    ShortcutHandler {
        name: "KTabLand Group With Window Below"
        text: "KTabLand: Group the active window with the window under it"
        sequence: ""
        onActivated: root.manager.groupActiveWithBelow()
    }

    ShortcutHandler {
        name: "KTabLand Release Tab"
        text: "KTabLand: Release the active tab from its group"
        sequence: ""
        onActivated: root.manager.detachActive()
    }

    ShortcutHandler {
        name: "KTabLand Tab Options"
        text: "KTabLand: Name and color of the active tab"
        sequence: ""
        onActivated: {
            const window = Workspace.activeWindow;
            if (window && root.manager.groupOf(window)) {
                root.manager.openTabOptions(window, null, root.barWindow(root.manager.groupOf(window).id));
            }
        }
    }

    ShortcutHandler {
        name: "KTabLand Debug Drop Preview"
        text: "KTabLand: Show the drop feedback for the active window (debug)"
        sequence: ""
        onActivated: root.manager.debugDropPreview()
    }

    ShortcutHandler {
        name: "KTabLand Debug Dump"
        text: "KTabLand: Print the groups to the log (debug)"
        sequence: ""
        onActivated: root.manager.dump()
    }

    // KWin re-reads its config (System Settings › KWin Scripts › Apply) without restarting
    // scripts, so settings are applied live and groups survive.
    Connections {
        target: Options
        function onConfigChanged() {
            root.config = root.readSettings();
            root.bump();
        }
    }

    Component.onCompleted: {
        manager = new Core.Manager({
            workspace: Workspace,
            clientArea: (window) => Workspace.clientArea(KWin.MaximizeArea, window),
            config: () => root.config,
            changed: () => Qt.callLater(root.bump),
            later: (fn) => Qt.callLater(fn),
            openTabOptions: (window, position, parentWindow) => {
                try {
                    root.tabOptions.open(window, position, parentWindow);
                } catch (e) {
                    root.log("cannot open the tab options: " + e);
                }
            },
            groupAdded: (id) => groupModel.append({ gid: id }),
            groupRemoved: (id) => {
                for (let i = 0; i < groupModel.count; i++) {
                    if (groupModel.get(i).gid === id) {
                        groupModel.remove(i);
                        return;
                    }
                }
            },
            dragStarted: () => {
                loadModifierWatcher.call();
                dragPoll.start();
            },
            dragEnded: () => dragPoll.stop(),
            highlight: (rect, window) => {
                if (root.highlight) {
                    root.highlight.showAt(rect, window);
                }
            },
            log: root.log,
            debug: (message) => {
                if (root.config.debug) {
                    root.log(message);
                }
            },
        });
        manager.start();
        log("started");
        if (config.debug) {
            log("settings " + JSON.stringify(config));
        }
    }

    Component.onDestruction: {
        dragPoll.stop();
        if (manager) {
            manager.stop();
        }
        log("stopped, all windows given back");
    }
}
