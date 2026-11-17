// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents

// Popup of the "+" button: pick a window to add to the group. Type to filter,
// Up / Down and Enter, or click.
Window {
    id: picker

    property var manager: null
    property var group: null
    property var candidates: []

    readonly property var shown: {
        const query = search.text.trim().toLowerCase();
        if (!query) {
            return candidates;
        }
        return candidates.filter((window) => window.caption.toLowerCase().includes(query)
            || picker.manager.appId(window).toLowerCase().includes(query));
    }

    function open(targetGroup, position, parentWindow) {
        group = targetGroup;
        candidates = manager.addCandidates(targetGroup);
        search.text = "";
        list.currentIndex = 0;
        transientParent = parentWindow ?? null;
        const screen = KWinComponents.Workspace.screenAt(Qt.point(position.x, position.y));
        const area = screen ? screen.geometry : Qt.rect(0, 0, 1e6, 1e6);
        x = Math.round(Math.max(area.x, Math.min(position.x, area.x + area.width - width)));
        y = Math.round(Math.max(area.y, Math.min(position.y, area.y + area.height - height)));
        visible = true;
        search.forceActiveFocus();
    }

    function close() {
        visible = false;
        group = null;
        candidates = [];
    }

    function pick(window) {
        const target = group;
        close();
        if (window && target) {
            manager.guard(() => manager.addToGroup(target, window));
        }
    }

    flags: Qt.Popup | Qt.FramelessWindowHint
    color: "transparent"
    title: "KTabLand add window"
    width: Kirigami.Units.gridUnit * 24
    height: Kirigami.Units.gridUnit * 18
    visible: false

    Rectangle {
        anchors.fill: parent

        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false

        radius: Kirigami.Units.cornerRadius * 2
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: "Add a window to this group"
                font.bold: true
            }

            QQC2.TextField {
                id: search
                Layout.fillWidth: true
                placeholderText: "Search windows…"
                onTextChanged: list.currentIndex = 0
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onEscapePressed: picker.close()
                onAccepted: picker.pick(picker.shown[list.currentIndex])
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: picker.shown
                highlightMoveDuration: 0

                QQC2.Label {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No other window"
                    opacity: 0.6
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property bool grouped: picker.manager.groupOf(modelData) !== null
                    width: ListView.view.width
                    height: Kirigami.Units.gridUnit * 2.2
                    radius: Kirigami.Units.cornerRadius
                    color: current || rowMouse.containsMouse ? Kirigami.Theme.highlightColor : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                        spacing: Kirigami.Units.smallSpacing * 2

                        Kirigami.Icon {
                            source: row.modelData.icon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: row.modelData.caption
                                elide: Text.ElideRight
                                color: row.current || rowMouse.containsMouse ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: picker.manager.appId(row.modelData) + (row.grouped ? " · in another group" : "")
                                    + (row.modelData.minimized ? " · minimized" : "")
                                elide: Text.ElideRight
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                color: row.current || rowMouse.containsMouse ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: picker.pick(row.modelData)
                    }
                }
            }
        }
    }
}
