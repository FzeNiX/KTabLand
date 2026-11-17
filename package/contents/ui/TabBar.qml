// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kwin

// Content of the tab bar of one group. SolidBar.qml / TranslucentBar.qml put it in a KWin
// internal window placed by the script above the group's active window (or over its top
// edge when there is no room above).
Item {
    id: bar

    // The window holding this bar (for global coordinates) and whether that window draws
    // a translucent Plasma background itself.
    property var hostWindow: null
    property bool translucent: false

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
    // Above the window the bar is the group's title bar: tabs, a free part to drag the
    // group, and minimize / maximize buttons. Over a maximized window (the app's own
    // title bar and buttons are there) it only holds the tabs.
    readonly property real buttonSize: Math.max(16, Math.min(height, config.tabBarHeight) - 8)
    // Width of one button column: Breeze's default button spacing (46 px at 10 pt), so
    // that the group's buttons sit right above the app's.
    readonly property real buttonColumn: Math.round(Kirigami.Units.gridUnit * 2.55)
    // Color of the squares filling the window's corners under the bar (CornerEars).
    readonly property color cornerColor: translucent
        ? Qt.rgba(content.Kirigami.Theme.backgroundColor.r, content.Kirigami.Theme.backgroundColor.g, content.Kirigami.Theme.backgroundColor.b, 0.85)
        : content.Kirigami.Theme.backgroundColor
    readonly property real plusWidth: inside ? 0 : buttonSize + 2 * Kirigami.Units.smallSpacing
    readonly property real controlsWidth: inside ? 0 : Kirigami.Units.gridUnit * 3 + 3 * buttonColumn + plusWidth
    readonly property real tabWidth: windows.length > 0
        ? Math.max(0, Math.min(config.tabWidth, (width - 2 * Kirigami.Units.smallSpacing - controlsWidth) / windows.length)) : 0

    // Tab being dragged, and whether the pointer left the bar.
    property var draggedWindow: null
    property bool draggedOut: false

    readonly property bool shown: (revision, group !== null && place !== null && manager.isBarShown(groupId)) || draggedWindow !== null

    function containsGlobal(position, margin) {
        const w = hostWindow;
        return position.x >= w.x - margin && position.x < w.x + w.width + margin
            && position.y >= w.y - margin && position.y < w.y + w.height + margin;
    }

    Item {
        id: content
        anchors.fill: parent

        Kirigami.Theme.colorSet: Kirigami.Theme.Header
        Kirigami.Theme.inherit: false

        // Strip behind the tabs. Over a window (no room above it), the bar is a
        // rounded floating strip instead of a full-width one.
        Rectangle {
            visible: !bar.translucent
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
                    // Name and color given by the user (right click).
                    readonly property var info: (bar.revision, bar.manager.tabInfo(modelData))
                    readonly property color tint: info.color || "transparent"
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
                            if (tab.info.color) {
                                return Qt.rgba(tab.tint.r, tab.tint.g, tab.tint.b, tab.current ? 0.4 : tabMouse.containsMouse ? 0.3 : 0.2);
                            }
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
                            color: tab.info.color || Kirigami.Theme.highlightColor
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
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                        onPressed: (mouse) => {
                            pressPoint = Qt.point(mouse.x, mouse.y);
                            dragging = false;
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed || !(pressedButtons & Qt.LeftButton) || (pressedButtons & Qt.RightButton)) {
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
                            } else if (mouse.button === Qt.RightButton) {
                                const p = tab.mapToItem(null, mouse.x, tab.height);
                                bar.manager.openTabMenu(tab.modelData, { x: bar.hostWindow.x + p.x, y: bar.hostWindow.y + p.y }, bar.hostWindow);
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
                            text: tab.info.name || tab.modelData.caption
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

        // "+": add a window to the group (like a browser's new tab button).
        Item {
            id: plusButton
            visible: !bar.inside && bar.windows.length > 0
            x: tabs.x + tabs.width + Kirigami.Units.smallSpacing
            anchors.verticalCenter: tabs.verticalCenter
            width: bar.buttonSize
            height: bar.buttonSize

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: {
                    const c = Kirigami.Theme.textColor;
                    return Qt.rgba(c.r, c.g, c.b, plusMouse.pressed ? 0.2 : plusMouse.containsMouse ? 0.1 : 0);
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 11
                height: 1.2
                color: Kirigami.Theme.textColor
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1.2
                height: 11
                color: Kirigami.Theme.textColor
            }
            MouseArea {
                id: plusMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    const p = plusButton.mapToItem(null, 0, plusButton.height);
                    bar.manager.openWindowPicker(bar.group, { x: bar.hostWindow.x + p.x, y: bar.hostWindow.y + p.y + 4 }, bar.hostWindow);
                }
            }
        }

        Row {
            id: controls
            visible: !bar.inside
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: 0

            // Drawn like Breeze's own title bar buttons (icon themes often have arrows),
            // in columns as wide as Breeze's, so they line up with the app's buttons below.
            component BarButton: Item {
                id: button
                signal clicked()
                default property alias glyph: glyphArea.data
                property bool danger: false
                readonly property bool hovered: buttonMouse.containsMouse
                width: bar.buttonColumn
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: bar.buttonSize
                    height: bar.buttonSize
                    radius: width / 2
                    color: {
                        if (button.danger && (buttonMouse.containsMouse || buttonMouse.pressed)) {
                            return buttonMouse.pressed ? Qt.darker(Kirigami.Theme.negativeTextColor, 1.2) : Kirigami.Theme.negativeTextColor;
                        }
                        const c = Kirigami.Theme.textColor;
                        return Qt.rgba(c.r, c.g, c.b, buttonMouse.pressed ? 0.2 : buttonMouse.containsMouse ? 0.1 : 0);
                    }
                }
                Item {
                    id: glyphArea
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                }
                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: button.clicked()
                }
            }

            BarButton {
                onClicked: bar.manager.minimizeGroup(bar.group)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Kirigami.Theme.textColor
                }
            }

            BarButton {
                id: maximizeButton
                readonly property bool maximized: (bar.revision, bar.group && bar.activeWindow ? bar.manager.isMaximized(bar.group) : false)
                onClicked: bar.manager.toggleMaximize(bar.group)
                Rectangle {
                    visible: !maximizeButton.maximized
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Kirigami.Theme.textColor
                }
                // Restore: two overlapping squares.
                Item {
                    visible: maximizeButton.maximized
                    anchors.fill: parent
                    Rectangle {
                        x: 2; y: 0; width: 8; height: 8
                        color: "transparent"
                        border.width: 1
                        border.color: Kirigami.Theme.textColor
                    }
                    Rectangle {
                        x: 0; y: 2; width: 8; height: 8
                        color: Kirigami.Theme.backgroundColor
                        border.width: 1
                        border.color: Kirigami.Theme.textColor
                    }
                }
            }

            // Closes every window of the group.
            BarButton {
                id: closeGroupButton
                danger: true
                onClicked: bar.manager.closeGroup(bar.group)
                Repeater {
                    model: [45, -45]
                    Rectangle {
                        required property int modelData
                        anchors.centerIn: parent
                        width: 13
                        height: 1.2
                        rotation: modelData
                        antialiasing: true
                        color: closeGroupButton.hovered ? "white" : Kirigami.Theme.textColor
                    }
                }
            }
        }
    }
}
