// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents

// Name and color of a tab, shown under the tab that was right clicked. KWin gives the
// keyboard only to its internal windows that are popups (Qt.Popup), and closes a popup
// when the user clicks elsewhere.
Window {
    id: popup

    property var manager: null
    property var window: null
    property string tabColor: ""

    readonly property var palette: ["", "#e5484d", "#f76b15", "#ffc53d", "#46a758", "#12a594", "#0090ff", "#8e4ec6", "#d6409f", "#8d8d8d"]

    // `position`: global point the popup hangs from (bottom of the tab, or the cursor).
    function open(target, position, parentWindow) {
        window = target;
        transientParent = parentWindow ?? null;
        tabColor = manager.tabInfo(target).color;
        nameField.text = manager.tabInfo(target).name;
        const screen = KWinComponents.Workspace.screenAt(Qt.point(position.x, position.y));
        const area = screen ? screen.geometry : Qt.rect(0, 0, 1e6, 1e6);
        x = Math.round(Math.max(area.x, Math.min(position.x, area.x + area.width - width)));
        y = Math.round(Math.max(area.y, Math.min(position.y, area.y + area.height - height)));
        visible = true;
        nameField.forceActiveFocus();
        nameField.selectAll();
    }

    function close() {
        visible = false;
        window = null;
    }

    function apply() {
        if (window && !window.deleted) {
            manager.setTabInfo(window, nameField.text.trim(), tabColor);
        }
        close();
    }

    flags: Qt.Popup | Qt.FramelessWindowHint
    color: "transparent"
    title: "KTabLand tab options"
    width: Kirigami.Units.gridUnit * 20
    height: card.implicitHeight + 2 * Kirigami.Units.largeSpacing
    visible: false
    onVisibleChanged: if (manager && manager.host.config().debug) console.info("KTabLand: tab options popup visible", visible, x, y, width, height)

    Rectangle {
        anchors.fill: parent

        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false

        radius: Kirigami.Units.cornerRadius * 2
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)

        ColumnLayout {
            id: card
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: "Tab name"
            }

            QQC2.TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: popup.window ? popup.window.caption : ""
                onAccepted: popup.apply()
                Keys.onEscapePressed: popup.close()
            }

            QQC2.Label {
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "Color"
            }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: popup.palette

                    delegate: Rectangle {
                        id: swatch
                        required property string modelData
                        readonly property bool selected: popup.tabColor === modelData
                        width: Kirigami.Units.gridUnit * 1.4
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
                            onClicked: popup.tabColor = swatch.modelData
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
                        nameField.text = "";
                        popup.tabColor = "";
                        popup.apply();
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                QQC2.Button {
                    text: "Cancel"
                    onClicked: popup.close()
                }
                QQC2.Button {
                    text: "OK"
                    highlighted: true
                    onClicked: popup.apply()
                }
            }
        }
    }
}
