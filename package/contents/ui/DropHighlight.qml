// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Shows where a dragged window or tab will go. For a window about to be grouped, it also
// previews the tab it will become, at the top of the target.
Window {
    id: highlight

    // Window that will become a tab (null: plain highlight, e.g. for a dragged tab).
    property var preview: null

    function showAt(rect, window) {
        if (!rect) {
            visible = false;
            preview = null;
            return;
        }
        preview = window ?? null;
        x = Math.round(rect.x);
        y = Math.round(rect.y);
        width = Math.max(1, Math.round(rect.width));
        height = Math.max(1, Math.round(rect.height));
        if (!visible) {
            visible = true;
            appear.restart();
        }
    }

    flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint | Qt.WindowTransparentForInput
    color: "transparent"
    title: "KTabLand drop highlight"
    visible: false

    Item {
        id: content
        anchors.fill: parent
        transformOrigin: Item.Center

        // Pops in, so the change is noticed even at the edge of the eye.
        ParallelAnimation {
            id: appear
            NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
            NumberAnimation { target: content; property: "scale"; from: 0.97; to: 1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack }
        }

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.18)
        }

        // Slowly pulsing border.
        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: "transparent"
            border.color: Kirigami.Theme.highlightColor
            border.width: 3

            SequentialAnimation on opacity {
                running: highlight.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.45; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.45; to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
        }

        // The tab the dragged window is about to become.
        Rectangle {
            visible: highlight.preview !== null
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Kirigami.Units.smallSpacing * 2
            width: Math.min(parent.width - 4 * Kirigami.Units.smallSpacing, label.implicitWidth + 2 * Kirigami.Units.largeSpacing)
            height: Kirigami.Units.gridUnit * 2
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.highlightColor

            RowLayout {
                id: label
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: highlight.preview ? highlight.preview.icon : ""
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }
                Text {
                    text: highlight.preview ? highlight.preview.caption : ""
                    elide: Text.ElideRight
                    color: Kirigami.Theme.highlightedTextColor
                    font.bold: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                }
                Text {
                    text: "— drop to add as a tab"
                    color: Kirigami.Theme.highlightedTextColor
                    opacity: 0.85
                }
            }
        }
    }
}
