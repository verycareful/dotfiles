// One app's group in the centre: header (icon · name · count · collapse · close-all) + its cards.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."
import "../services"

ColumnLayout {
    id: group
    required property var g            // Notifs.Group
    spacing: 4

    // header
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85)
        border.width: 1; border.color: Theme.overlay

        MouseArea { anchors.fill: parent; onClicked: Notifs.toggleGroup(group.g) }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
            spacing: 8
            IconImage { implicitSize: 18; source: Quickshell.iconPath(group.g.icon, "dialog-information") }
            Text {
                text: group.g.app
                color: Theme.text
                font { family: Theme.fontDisplay; pixelSize: 14; weight: Font.Bold }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {                       // count badge
                implicitWidth: Math.max(22, countLabel.implicitWidth + 12); implicitHeight: 20
                color: group.g.unreadCount > 0 ? Theme.accent : Theme.overlay
                Text {
                    id: countLabel
                    anchors.centerIn: parent
                    text: group.g.count
                    color: group.g.unreadCount > 0 ? Theme.base : Theme.subtext
                    font { family: Theme.fontUi; pixelSize: 11; weight: Font.Bold }
                }
            }
            HeaderButton { glyph: group.g.collapsed ? "\u{F0142}" : "\u{F0140}"; onClicked: Notifs.toggleGroup(group.g) }   // chevron right / down
            HeaderButton { glyph: "\u{F0156}"; hot: true; onClicked: Notifs.closeGroup(group.g) }                          // close all
        }
    }

    // cards (hidden while collapsed)
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        visible: !group.g.collapsed
        spacing: 4
        Repeater {
            model: group.g.items
            Card { required property var modelData; entry: modelData; Layout.fillWidth: true }
        }
    }

    component HeaderButton: Rectangle {
        property string glyph
        property bool hot: false
        signal clicked
        implicitWidth: 26; implicitHeight: 26
        color: hb.containsMouse ? Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9) : "transparent"
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: hb.containsMouse ? (parent.hot ? Theme.red : Theme.accent) : Theme.subtext
            font { family: Theme.fontIcon; pixelSize: 15 }
        }
        MouseArea { id: hb; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
