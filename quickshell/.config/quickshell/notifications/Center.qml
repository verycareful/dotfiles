// Notification centre: full-height panel on the right. Esc, the bar bell, SUPER+Shift+N
// or a click anywhere outside closes it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

Scope {
    // click-catcher: covers everything except the panel itself (same layer, so it must not overlap)
    PanelWindow {
        visible: Notifs.centerOpen
        anchors { top: true; bottom: true; left: true; right: true }
        margins { right: 400 }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-notif-catcher"
        MouseArea { anchors.fill: parent; onClicked: Notifs.setCenter(false) }
    }

    PanelWindow {
        id: win
        visible: Notifs.centerOpen
        anchors { top: true; bottom: true; right: true }
        implicitWidth: 400
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-notif-center"
        WlrLayershell.keyboardFocus: Notifs.centerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Theme.glassPanel
            focus: true
            Keys.onEscapePressed: Notifs.setCenter(false)
            Rectangle { width: 1; height: parent.height; color: Theme.overlay }   // inner edge

            ColumnLayout {
                anchors { fill: parent; margins: 12; leftMargin: 14 }
                spacing: 10

                // title row
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Notifications"
                        color: Theme.text
                        font { family: Theme.fontDisplay; pixelSize: 16; weight: Font.Bold }
                        Layout.fillWidth: true
                    }
                    TextButton { label: "Read all"; visible: Notifs.unread > 0; onClicked: Notifs.markAllRead() }
                    TextButton { label: "Clear";    visible: Notifs.groups.length > 0; onClicked: Notifs.clearAll() }
                }

                // do not disturb
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                    border.width: 1; border.color: Theme.overlay
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        Text {
                            Layout.fillWidth: true
                            text: "Do not disturb"; color: Theme.subtext
                            font { family: Theme.fontUi; pixelSize: Theme.fontSize }
                        }
                        Rectangle {                                        // switch
                            implicitWidth: 38; implicitHeight: 20
                            color: Notifs.dnd ? Theme.primary : Theme.overlay
                            border.width: 1; border.color: Notifs.dnd ? Theme.primaryBright : Theme.muted
                            Rectangle {
                                width: 14; height: 14; y: 3
                                x: Notifs.dnd ? parent.width - width - 3 : 3
                                color: Notifs.dnd ? Theme.accent : Theme.subtext
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: Notifs.setDnd(!Notifs.dnd) }
                        }
                    }
                }

                // groups
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent
                        contentHeight: list.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: list
                            width: parent.width
                            spacing: 10
                            Repeater {
                                model: Notifs.groups
                                Group { required property var modelData; g: modelData; Layout.fillWidth: true }
                            }
                        }
                    }
                    Text {                        // outside the Flickable: its content item is 0 px tall when empty
                        anchors.centerIn: parent
                        visible: Notifs.groups.length === 0
                        text: "Nothing here"
                        color: Theme.muted
                        font { family: Theme.fontUi; pixelSize: Theme.fontSize }
                    }
                }
            }
        }
    }

    component TextButton: Rectangle {
        property string label
        signal clicked
        implicitWidth: tl.implicitWidth + 16; implicitHeight: 24
        color: "transparent"
        border.width: 1; border.color: th.containsMouse ? Theme.accent : Theme.overlay
        Text { id: tl; anchors.centerIn: parent; text: parent.label; color: th.containsMouse ? Theme.accent : Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
        MouseArea { id: th; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
