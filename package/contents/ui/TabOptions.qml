// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents

// Name and color of a tab. KWin gives no keyboard to the tab bar windows, so this is a
// scene effect (like Overview): a dimmed screen with a small card that takes typing.
KWinComponents.SceneEffect {
    id: effect

    property var manager: null
    property var window: null
    property var screen: null
    property string color: ""

    readonly property var palette: ["", "#e5484d", "#f76b15", "#ffc53d", "#46a758", "#12a594", "#0090ff", "#8e4ec6", "#d6409f", "#8d8d8d"]

    function open(target) {
        window = target;
        screen = KWinComponents.Workspace.screenAt(KWinComponents.Workspace.cursorPos);
        color = manager.tabInfo(target).color;
        visible = true;
    }

    function close() {
        visible = false;
        window = null;
    }

    function apply(name) {
        if (window && !window.deleted) {
            manager.setTabInfo(window, name.trim(), color);
        }
        close();
    }

    visible: false

    delegate: Item {
        id: view

        readonly property bool here: KWinComponents.SceneView.screen === effect.screen

        Kirigami.Theme.colorSet: Kirigami.Theme.View
        Kirigami.Theme.inherit: false

        // Click outside the card: cancel.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            MouseArea {
                anchors.fill: parent
                onClicked: effect.close()
            }
        }

        Rectangle {
            visible: view.here
            anchors.centerIn: parent
            width: Kirigami.Units.gridUnit * 24
            height: card.implicitHeight + 2 * Kirigami.Units.largeSpacing
            radius: Kirigami.Units.cornerRadius * 2
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)

            // Swallow clicks on the card itself.
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: card
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 3
                    text: "Tab name and color"
                }

                QQC2.TextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: effect.window ? effect.window.caption : ""
                    text: effect.window ? effect.manager.tabInfo(effect.window).name : ""
                    onAccepted: effect.apply(text)
                    Keys.onEscapePressed: effect.close()
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: effect.palette

                        delegate: Rectangle {
                            id: swatch
                            required property string modelData
                            readonly property bool selected: effect.color === modelData
                            width: Kirigami.Units.gridUnit * 1.5
                            height: width
                            radius: width / 2
                            color: modelData || "transparent"
                            border.width: selected ? 3 : 1
                            border.color: selected ? Kirigami.Theme.highlightColor
                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)

                            // "No color": a slashed circle.
                            Rectangle {
                                visible: !swatch.modelData
                                anchors.centerIn: parent
                                width: parent.width * 0.7
                                height: 1.5
                                rotation: -45
                                antialiasing: true
                                color: Kirigami.Theme.textColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: effect.color = swatch.modelData
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        text: "Reset"
                        onClicked: {
                            effect.color = "";
                            effect.apply("");
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    QQC2.Button {
                        text: "Cancel"
                        onClicked: effect.close()
                    }
                    QQC2.Button {
                        text: "OK"
                        highlighted: true
                        onClicked: effect.apply(nameField.text)
                    }
                }
            }
        }

        Component.onCompleted: {
            if (here) {
                nameField.forceActiveFocus();
                nameField.selectAll();
            }
        }
    }
}
