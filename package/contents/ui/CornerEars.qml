// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window

// Two small squares hanging under the ends of a tab bar, in the bar's color: they fill
// the gaps left by the rounded top corners of the window below. Clicks go through them.
QtObject {
    id: ears

    property var bar: null          // the tab bar window
    property bool active: false
    property int size: 6

    property color color: "transparent"

    property Window left: Window {
        flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint | Qt.WindowTransparentForInput
        title: "United Sets X tab bar corner"
        color: ears.color
        x: ears.bar ? ears.bar.x : 0
        y: ears.bar ? ears.bar.y + ears.bar.height : 0
        width: ears.size
        height: ears.size
        visible: ears.active && ears.size > 0
    }

    property Window right: Window {
        flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint | Qt.WindowTransparentForInput
        title: "United Sets X tab bar corner"
        color: ears.color
        x: ears.bar ? ears.bar.x + ears.bar.width - ears.size : 0
        y: ears.bar ? ears.bar.y + ears.bar.height : 0
        width: ears.size
        height: ears.size
        visible: ears.active && ears.size > 0
    }
}
