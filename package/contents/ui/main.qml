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

    // Flag effects loaded by the unitedsetsx_modwatch effect while a modifier is held,
    // indexed like the GroupModifier setting.
    readonly property var modifierFlags: ["unitedsetsx_mod_shift", "unitedsetsx_mod_ctrl", "unitedsetsx_mod_alt", "unitedsetsx_mod_meta"]

    function readSettings() {
        return {
            modifier: Number(KWin.readConfig("GroupModifier", 1)),
            showTabBar: Boolean(KWin.readConfig("ShowTabBar", true)),
            tabBarHeight: Number(KWin.readConfig("TabBarHeight", 32)),
            tabWidth: Number(KWin.readConfig("TabWidth", 220)),
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
        console.info("UnitedSetsX:", message);
    }

    ListModel {
        id: groupModel
    }

    Instantiator {
        id: bars
        model: groupModel
        delegate: TabBar {
            required property int gid
            groupId: gid
            manager: root.manager
            revision: root.revision
            config: root.config
        }
    }

    DropHighlight {
        id: highlight
    }

    DBusCall {
        id: loadModifierWatcher
        service: "org.kde.KWin"
        path: "/Effects"
        dbusInterface: "org.kde.kwin.Effects"
        method: "loadEffect"
        arguments: ["unitedsetsx_modwatch"]
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
        name: "UnitedSetsX Next Tab"
        text: "United Sets X: Next tab"
        sequence: "Meta+`"
        onActivated: root.manager.cycle(1)
    }

    ShortcutHandler {
        name: "UnitedSetsX Previous Tab"
        text: "United Sets X: Previous tab"
        sequence: "Meta+~"
        onActivated: root.manager.cycle(-1)
    }

    ShortcutHandler {
        name: "UnitedSetsX Group With Window Below"
        text: "United Sets X: Group the active window with the window under it"
        sequence: ""
        onActivated: root.manager.groupActiveWithBelow()
    }

    ShortcutHandler {
        name: "UnitedSetsX Release Tab"
        text: "United Sets X: Release the active tab from its group"
        sequence: ""
        onActivated: root.manager.detachActive()
    }

    ShortcutHandler {
        name: "UnitedSetsX Debug Dump"
        text: "United Sets X: Print the groups to the log (debug)"
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
            highlight: (rect) => highlight.showAt(rect),
            log: root.log,
            debug: (message) => {
                if (root.config.debug) {
                    root.log(message);
                }
            },
        });
        manager.start();
        log("started");
    }

    Component.onDestruction: {
        dragPoll.stop();
        if (manager) {
            manager.stop();
        }
        log("stopped, all windows given back");
    }
}
