// Calendar popup: a month calendar dropping down under the bar's date, today highlighted, ‹ › browse.
// Clicking the date opens and closes it; Escape or a click outside closes it. It opens under the pointer,
// which is on the date when the bar's click opens it.
//   qs ipc call calendar open|close|toggle   (the bar's date)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../panel"

Scope {
    id: root
    property bool open: false
    property int pointerX: 0
    readonly property int cardW: 300

    function show() { where.running = true }
    function hide() { open = false }

    // `hyprctl cursorpos` gives global coordinates; the bar sits on the focused monitor
    Process {
        id: where
        command: ["sh", "-c", "hyprctl cursorpos -j; hyprctl monitors -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split(/\n(?=\[)/)
                    const pos = JSON.parse(parts[0]), mon = JSON.parse(parts[1]).find(m => m.focused)
                    root.pointerX = pos.x - (mon ? mon.x : 0)
                } catch (e) { root.pointerX = 0 }
                cal.shown = new Date(); cal.today = new Date()
                root.open = true
            }
        }
    }

    IpcHandler {
        target: "calendar"
        function open(): void   { root.show() }
        function close(): void  { root.hide() }
        function toggle(): void { if (root.open) root.hide(); else root.show() }
    }

    // click-catcher: the whole screen below the popup's layer
    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-calendar-catcher"
        MouseArea { anchors.fill: parent; onClicked: root.hide() }
    }
    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; left: true }
        margins.left: Math.max(8, Math.min(screen.width - root.cardW - 8, root.pointerX - root.cardW / 2))
        implicitWidth: root.cardW
        implicitHeight: body.implicitHeight
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-calendar"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top }
            implicitHeight: cal.implicitHeight + 16
            color: Theme.glassPanel
            border.width: 1; border.color: Theme.overlay
            focus: true
            Keys.onEscapePressed: root.hide()
            Month { id: cal; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 } }
        }
    }
}
