// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import QtQuick.Shapes

// Under the two ends of a tab bar, the bar's color wraps around the rounded top corners
// of the window below (a square with a quarter circle cut out), so the bar and the
// window look like one frame. Clicks go through.
QtObject {
    id: ears

    property var bar: null          // the tab bar window
    property bool active: false
    property int size: 8            // corner radius of the window below
    property color color: "transparent"

    property Window left: Window {
        flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint | Qt.WindowTransparentForInput
        title: "United Sets X tab bar corner"
        color: "transparent"
        x: ears.bar ? ears.bar.x : 0
        y: ears.bar ? ears.bar.y + ears.bar.height : 0
        width: ears.size
        height: ears.size
        visible: ears.active && ears.size > 0

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ears.color
                strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: ears.size; y: 0 }
                PathArc { x: 0; y: ears.size; radiusX: ears.size; radiusY: ears.size; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    property Window right: Window {
        flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint | Qt.WindowTransparentForInput
        title: "United Sets X tab bar corner"
        color: "transparent"
        x: ears.bar ? ears.bar.x + ears.bar.width - ears.size : 0
        y: ears.bar ? ears.bar.y + ears.bar.height : 0
        width: ears.size
        height: ears.size
        visible: ears.active && ears.size > 0

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ears.color
                strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: ears.size; y: 0 }
                PathLine { x: ears.size; y: ears.size }
                PathArc { x: 0; y: 0; radiusX: ears.size; radiusY: ears.size; direction: PathArc.Counterclockwise }
            }
        }
    }
}
