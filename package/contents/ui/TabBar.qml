// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kwin

// The tab bar of one group: a KWin internal window placed by the script above the
// group's active window (or over its top edge when there is no room above).
Window {
    id: bar

    property int groupId: 0
    property var manager: null
    property int revision: 0
    property var config: ({})

    readonly property var group: (revision, manager ? manager.group(groupId) : null)
    readonly property var activeWindow: (revision, group ? group.active : null)
    readonly property var windows: (revision, group ? group.windows.slice() : [])
    // Reading activeWindow.frameGeometry here makes the bar follow the window live.
    readonly property var place: (revision, group && activeWindow ? manager.barRect(group, activeWindow.frameGeometry) : null)
    readonly property bool inside: place ? place.inside : false
    readonly property real tabWidth: windows.length > 0
        ? Math.min(config.tabWidth, (width - 2 * Kirigami.Units.smallSpacing) / windows.length) : 0

    // Tab being dragged, and whether the pointer left the bar.
    property var draggedWindow: null
    property bool draggedOut: false

    flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint
    color: "transparent"
    title: "United Sets X tab bar"
    x: place ? Math.round(place.x) : 0
    y: place ? Math.round(place.y) : 0
    width: place ? Math.max(1, Math.round(place.width)) : 1
    height: place ? Math.max(1, Math.round(place.height)) : 1
    visible: (revision, group !== null && place !== null && manager.isBarShown(groupId)) || draggedWindow !== null

    onVisibleChanged: if (config.debug) console.info("UnitedSetsX: bar", groupId, "visible", visible, x, y, width, height)

    function containsGlobal(position, margin) {
        return position.x >= x - margin && position.x < x + width + margin
            && position.y >= y - margin && position.y < y + height + margin;
    }

    Item {
        id: content
        anchors.fill: parent

        Kirigami.Theme.colorSet: Kirigami.Theme.Header
        Kirigami.Theme.inherit: false

        // Strip behind the tabs. Over a window (no room above it), the bar is a
        // rounded floating strip instead of a full-width one.
        Rectangle {
            anchors.fill: parent
            anchors.margins: bar.inside ? 2 : 0
            radius: bar.inside ? Kirigami.Units.cornerRadius : 0
            color: Kirigami.Theme.backgroundColor
            border.width: bar.inside ? 1 : 0
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
        }

        // The empty part of the bar works like a title bar for the whole group: drag to
        // move it (a real KWin move, so snapping, tiling and drag-to-group work), double
        // click to maximize or restore it.
        MouseArea {
            id: stripMouse

            property point pressPoint

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton

            onPressed: (mouse) => {
                pressPoint = Qt.point(mouse.x, mouse.y);
            }
            onPositionChanged: (mouse) => {
                if (Math.abs(mouse.x - pressPoint.x) + Math.abs(mouse.y - pressPoint.y) >= Qt.styleHints.startDragDistance) {
                    bar.manager.moveGroup(bar.group);
                }
            }
            onDoubleClicked: bar.manager.toggleMaximize(bar.group)
        }

        Row {
            id: tabs
            x: Kirigami.Units.smallSpacing
            anchors.bottom: parent.bottom
            anchors.bottomMargin: bar.inside ? 3 : 0
            height: parent.height - (bar.inside ? 6 : 4)
            spacing: 0

            Repeater {
                model: bar.windows

                delegate: Item {
                    id: tab

                    required property var modelData
                    required property int index

                    readonly property bool current: modelData === bar.activeWindow
                    readonly property bool dragged: modelData === bar.draggedWindow
                    property real dragOffset: 0

                    width: bar.tabWidth
                    height: tabs.height
                    z: dragged ? 10 : 0
                    transform: Translate { x: tab.dragged && !bar.draggedOut ? tab.dragOffset : 0 }
                    opacity: tab.dragged && bar.draggedOut ? 0.5 : 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        radius: Kirigami.Units.cornerRadius
                        // Square bottom corners so the current tab joins the window below.
                        Rectangle {
                            visible: tab.current && !bar.inside
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.radius
                            color: parent.color
                        }
                        color: {
                            if (tab.current) {
                                return Kirigami.Theme.alternateBackgroundColor;
                            }
                            const c = Kirigami.Theme.textColor;
                            return Qt.rgba(c.r, c.g, c.b, tabMouse.containsMouse ? 0.08 : 0);
                        }

                        Rectangle {
                            visible: tab.current
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: parent.radius
                            anchors.rightMargin: parent.radius
                            height: 2
                            color: Kirigami.Theme.highlightColor
                        }
                    }

                    // Separator between two tabs that are not current or hovered.
                    Rectangle {
                        visible: !tab.current && tab.index > 0 && bar.windows[tab.index - 1] !== bar.activeWindow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: parent.height * 0.5
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                    }

                    MouseArea {
                        id: tabMouse

                        property point pressPoint
                        property bool dragging: false

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onPressed: (mouse) => {
                            pressPoint = Qt.point(mouse.x, mouse.y);
                            dragging = false;
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed || !(pressedButtons & Qt.LeftButton)) {
                                return;
                            }
                            if (!dragging && Math.abs(mouse.x - pressPoint.x) + Math.abs(mouse.y - pressPoint.y) >= Qt.styleHints.startDragDistance) {
                                dragging = true;
                                bar.draggedWindow = tab.modelData;
                            }
                            if (dragging) {
                                const position = Workspace.cursorPos;
                                bar.draggedOut = !bar.containsGlobal(position, Kirigami.Units.gridUnit);
                                tab.dragOffset = mouse.x - pressPoint.x;
                                bar.manager.tabDragged(bar.group, position);
                            }
                        }
                        onReleased: (mouse) => {
                            if (dragging) {
                                const position = Workspace.cursorPos;
                                const window = tab.modelData;
                                const out = !bar.containsGlobal(position, Kirigami.Units.gridUnit);
                                const index = Math.floor((tab.x + tab.width / 2 + tab.dragOffset) / bar.tabWidth);
                                dragging = false;
                                tab.dragOffset = 0;
                                bar.draggedWindow = null;
                                bar.draggedOut = false;
                                if (out) {
                                    bar.manager.tabDropped(bar.group, window, position);
                                } else {
                                    bar.manager.tabDragged(bar.group, position);
                                    bar.manager.reorder(bar.group, window, index);
                                }
                            } else if (mouse.button === Qt.MiddleButton) {
                                bar.manager.closeTab(tab.modelData);
                            } else {
                                bar.manager.activate(bar.group, tab.modelData);
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: tab.modelData.icon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }

                        Text {
                            text: tab.modelData.caption
                            elide: Text.ElideRight
                            color: Kirigami.Theme.textColor
                            opacity: tab.current ? 1 : 0.75
                            font: Kirigami.Theme.defaultFont
                            Layout.fillWidth: true
                        }

                        // Close button (visible on the current or hovered tab).
                        Rectangle {
                            id: closeButton
                            visible: tab.current || tabMouse.containsMouse || closeMouse.containsMouse
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small + 4
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small + 4
                            radius: width / 2
                            color: {
                                const c = Kirigami.Theme.textColor;
                                return Qt.rgba(c.r, c.g, c.b, closeMouse.containsMouse ? 0.15 : 0);
                            }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.small - 2
                                height: width
                                source: "window-close-symbolic"
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: bar.manager.closeTab(tab.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
