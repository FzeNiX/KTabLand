// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore

// Translucent tab bar: drawn with the Plasma theme's dialog background, which KWin blurs
// like the panel and its popups.
PlasmaCore.Window {
    id: win

    property int groupId: 0
    property var manager: null
    property int revision: 0
    property var config: ({})

    flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint
    title: "KTabLand tab bar"
    backgroundHints: PlasmaCore.Window.StandardBackground
    x: strip.place ? Math.round(strip.place.x) : 0
    y: strip.place ? Math.round(strip.place.y) : 0
    width: strip.place ? Math.max(1, Math.round(strip.place.width)) : 1
    height: strip.place ? Math.max(1, Math.round(strip.place.height)) : 1
    visible: strip.shown

    CornerEars {
        bar: win
        // Only where the window below has rounded corners.
        active: win.visible && strip.place !== null && !strip.inside && strip.group !== null
            && (win.revision, win.manager.hasRoundedTop(strip.group))
        size: win.config.cornerFill
        color: strip.cornerColor
    }

    onVisibleChanged: if (config.debug) console.info("KTabLand: bar", groupId, "visible", visible, x, y, width, height, "translucent", strip.width, strip.height, strip.buttonSize)

    // Not the mainItem: the bar uses the whole window, not only the inside of the Plasma
    // frame (its padding would leave too little height for the tabs).
    TabBar {
        id: strip
        width: win.width
        height: win.height
        hostWindow: win
        translucent: true
        groupId: win.groupId
        manager: win.manager
        revision: win.revision
        config: win.config
    }
}
