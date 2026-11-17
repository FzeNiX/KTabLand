// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents

// Right click menu of a tab. A popup (Qt.Popup) attached to the tab bar window: KWin
// closes it when the user clicks elsewhere.
Window {
    id: menu

    property var manager: null
    property var window: null
    property var group: null
    property var barWindow: null
    property point anchor
    // Rebuilt on open: [{ text, icon, action, separator }]
    property var entries: []

    signal renameRequested(var window, point position, var barWindow)

    function open(target, position, parentWindow) {
        window = target;
        group = manager.groupOf(target);
        barWindow = parentWindow;
        anchor = Qt.point(position.x, position.y);
        transientParent = parentWindow ?? null;
        entries = buildEntries();
        const screen = KWinComponents.Workspace.screenAt(Qt.point(position.x, position.y));
        const area = screen ? screen.geometry : Qt.rect(0, 0, 1e6, 1e6);
        x = Math.round(Math.max(area.x, Math.min(position.x, area.x + area.width - width)));
        y = Math.round(Math.max(area.y, Math.min(position.y, area.y + area.height - height)));
        visible = true;
        list.forceActiveFocus();
    }

    function close() {
        visible = false;
        window = null;
        group = null;
    }

    function buildEntries() {
        const items = [
            { text: "Name and color…", icon: "edit-rename", action: () => menu.renameRequested(menu.window, menu.anchor, menu.barWindow) },
            { text: "Release tab", icon: "view-split-left-right", action: () => manager.detach(menu.window, null) },
        ];
        for (const other of manager.otherGroups(group)) {
            const label = manager.tabLabel(other.active);
            items.push({ text: "Move to group: " + label, icon: "go-next", action: () => manager.moveToGroup(menu.window, other) });
        }
        items.push({ separator: true });
        items.push({ text: "Close tab", icon: "tab-close", action: () => manager.closeTab(menu.window) });
        if (group && group.windows.length > 1) {
            items.push({ text: "Close other tabs", icon: "tab-close-other", action: () => manager.closeOtherTabs(menu.group, menu.window) });
        }
        return items;
    }

    function trigger(entry) {
        const action = entry.action;
        close();
        manager.guard(action);
    }

    flags: Qt.Popup | Qt.FramelessWindowHint
    color: "transparent"
    title: "KTabLand tab menu"
    width: Kirigami.Units.gridUnit * 16
    height: list.contentHeight + 2 * Kirigami.Units.smallSpacing
    visible: false

    Rectangle {
        anchors.fill: parent

        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false

        radius: Kirigami.Units.cornerRadius * 2
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            interactive: false
            model: menu.entries
            currentIndex: -1
            keyNavigationEnabled: true

            Keys.onEscapePressed: menu.close()
            Keys.onReturnPressed: if (currentItem && !menu.entries[currentIndex].separator) menu.trigger(menu.entries[currentIndex])

            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                width: ListView.view.width
                height: modelData.separator ? Kirigami.Units.smallSpacing * 2 : Kirigami.Units.gridUnit * 1.8

                Rectangle {
                    visible: entry.modelData.separator === true
                    anchors.centerIn: parent
                    width: parent.width - 2 * Kirigami.Units.smallSpacing
                    height: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                }

                Rectangle {
                    visible: !entry.modelData.separator
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: mouse.containsMouse || entry.ListView.isCurrentItem ? Kirigami.Theme.highlightColor : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                        spacing: Kirigami.Units.smallSpacing * 2

                        Kirigami.Icon {
                            source: entry.modelData.icon ?? ""
                            color: mouse.containsMouse || entry.ListView.isCurrentItem ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        QQC2.Label {
                            text: entry.modelData.text ?? ""
                            elide: Text.ElideRight
                            color: mouse.containsMouse || entry.ListView.isCurrentItem ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: menu.trigger(entry.modelData)
                    }
                }
            }
        }
    }
}
