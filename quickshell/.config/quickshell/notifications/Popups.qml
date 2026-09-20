// Popup notifications: bottom-right, newest at the bottom, auto-hide (critical stays), hover pauses.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

PanelWindow {
    id: win
    visible: Notifs.popups.length > 0
    anchors { right: true; bottom: true }
    margins { right: 8; bottom: 8 }
    implicitWidth: 380
    implicitHeight: Math.max(1, col.implicitHeight)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notif-popups"

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 6
        Repeater {
            model: Notifs.popups
            Card {
                id: card
                required property var modelData
                entry: modelData
                popup: true
                Layout.fillWidth: true
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                Timer {
                    interval: card.n.urgency === 0 ? Notifs.popupTimeoutLow : Notifs.popupTimeout
                    running: card.n.urgency !== 2 && !hover.containsMouse
                    onTriggered: Notifs.hidePopup(card.entry)
                }
            }
        }
    }
}
