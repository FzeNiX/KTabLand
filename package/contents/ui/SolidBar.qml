// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window

// Opaque tab bar: a plain KWin internal window drawn with the color scheme's header color.
Window {
    id: win

    property int groupId: 0
    property var manager: null
    property int revision: 0
    property var config: ({})

    flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint
    color: "transparent"
    title: "United Sets X tab bar"
    x: strip.place ? Math.round(strip.place.x) : 0
    y: strip.place ? Math.round(strip.place.y) : 0
    width: strip.place ? Math.max(1, Math.round(strip.place.width)) : 1
    height: strip.place ? Math.max(1, Math.round(strip.place.height)) : 1
    visible: strip.shown

    CornerEars {
        bar: win
        active: win.visible && strip.place !== null && !strip.inside
        size: win.config.cornerFill
        color: strip.cornerColor
    }

    onVisibleChanged: if (config.debug) console.info("UnitedSetsX: bar", groupId, "visible", visible, x, y, width, height, "solid", strip.width, strip.height, strip.buttonSize)

    TabBar {
        id: strip
        anchors.fill: parent
        hostWindow: win
        groupId: win.groupId
        manager: win.manager
        revision: win.revision
        config: win.config
    }
}
