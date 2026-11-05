// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami

// Shows where a dragged window or tab will go.
Window {
    id: highlight

    function showAt(rect) {
        if (!rect) {
            visible = false;
            return;
        }
        x = Math.round(rect.x);
        y = Math.round(rect.y);
        width = Math.max(1, Math.round(rect.width));
        height = Math.max(1, Math.round(rect.height));
        visible = true;
    }

    flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint | Qt.WindowTransparentForInput
    color: "transparent"
    title: "United Sets X drop highlight"
    visible: false

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.18)
        border.color: Kirigami.Theme.highlightColor
        border.width: 3
    }
}
