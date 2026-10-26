// Alt-Tab window switcher: every window (all workspaces and scratchpads, not the tray), most-recently-used
// first, live thumbnails. Alt+Tab / Alt+Shift+Tab move the highlight, releasing Alt focuses that window
// on its own workspace, opening its scratchpad if it is in one (nothing is moved). Driven by Hyprland binds via `qs ipc call switcher …`.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../services"

Scope {
    id: root
    property bool shown: false
    property var list: []          // [HyprlandToplevel] MRU snapshot taken when the switcher opens
    property int index: 0

    // IPC details (focusHistoryID, class) arrive on refresh; keep them fresh on window events
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (["openwindow", "closewindow", "activewindow", "movewindow", "changefloatingmode"].includes(e.name)) Hyprland.refreshToplevels() }
    }
    function hist(t) { return t.lastIpcObject && t.lastIpcObject.focusHistoryID !== undefined ? t.lastIpcObject.focusHistoryID : 1e9 }
    // regular workspaces plus the scratchpads (special:scratch, scratch2, …); the tray stays hidden
    function listed(ws) { return ws && (ws.id > 0 || /^special:scratch\d*$/.test(ws.name)) }
    function snapshot() {
        const all = Hyprland.toplevels.values.filter(t => listed(t.workspace))
        all.sort((a, b) => hist(a) - hist(b))
        list = all
    }
    function step(d) {
        if (!shown) { snapshot(); if (list.length < 2) { list = []; return } index = 0; shown = true }
        index = (index + d + list.length) % list.length
    }
    function apply() {
        if (!shown) return
        const t = list[index]
        shown = false
        if (t) {
            const addr = "address:0x" + String(t.address).replace(/^0x/, "")
            // focusing a window in a hidden scratchpad does not open it, so open it first (unless it is already open)
            const ws = t.workspace.name
            const pad = ws.startsWith("special:") ? ws.slice(8) : ""
            Quickshell.execDetached(["sh", "-c",
                'if [ -n "$1" ] && [ "$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .specialWorkspace.name")" != "special:$1" ]; then ' +
                'hdsp "hl.dsp.workspace.toggle_special(\\"$1\\")" togglespecialworkspace "$1"; fi; ' +
                'hdsp "hl.dsp.focus({ window = \\"$2\\" })" focuswindow "$2"', "sh", pad, addr])
        }
        list = []
        Hyprland.refreshToplevels()
    }
    function cancel() { shown = false; list = [] }

    IpcHandler {
        target: "switcher"
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function apply(): void { root.apply() }
        function cancel(): void { root.cancel() }
    }

    PanelWindow {
        id: win
        visible: root.shown
        readonly property int cardW: 236
        readonly property int cardH: 176
        readonly property int gap: 12
        readonly property int cols: Math.max(1, Math.min(root.list.length, Math.floor((screen.width - 80 - 32 + gap) / (cardW + gap))))
        readonly property int rows: Math.ceil(root.list.length / cols)
        implicitWidth: cols * cardW + (cols - 1) * gap + 32
        implicitHeight: rows * cardH + (rows - 1) * gap + 32
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-switcher"

        Rectangle {
            anchors.fill: parent
            color: Theme.glassPanel
            border.width: 1; border.color: Theme.overlay
            Grid {
                id: grid
                anchors { fill: parent; margins: 16 }
                columns: win.cols
                spacing: win.gap
                Repeater {
                    model: root.list
                    Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.index
                        width: 236; height: 176
                        color: selected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) : Theme.glassCard
                        border.width: selected ? 2 : 1; border.color: selected ? Theme.accent : Theme.overlay
                        Column {
                            anchors { fill: parent; margins: 8 }
                            spacing: 6
                            Rectangle {                                     // thumbnail
                                width: parent.width; height: 124
                                color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.6)
                                clip: true
                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: card.modelData.wayland
                                    live: root.shown
                                    paintCursor: false
                                }
                                Rectangle {                                 // workspace tag
                                    anchors { left: parent.left; top: parent.top; margins: 4 }
                                    width: wsl.implicitWidth + 10; height: 18
                                    color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.85)
                                    Text { id: wsl; anchors.centerIn: parent; text: card.modelData.workspace ? card.modelData.workspace.name.replace(/^special:/, "") : ""; color: Theme.subtext; font { family: Theme.fontDisplay; pixelSize: 10; weight: Font.Bold } }
                                }
                            }
                            Row {
                                width: parent.width; spacing: 6
                                Image {
                                    width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                                    source: Quickshell.iconPath(card.modelData.lastIpcObject && card.modelData.lastIpcObject.class ? card.modelData.lastIpcObject.class.toLowerCase() : (card.modelData.wayland ? card.modelData.wayland.appId : ""), "application-x-executable")
                                    sourceSize: Qt.size(16, 16)
                                }
                                Text {
                                    width: parent.width - 22
                                    text: card.modelData.title
                                    color: card.selected ? Theme.text : Theme.subtext
                                    elide: Text.ElideRight
                                    font { family: Theme.fontUi; pixelSize: 12; weight: card.selected ? Font.Bold : Font.DemiBold }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.index = card.index; root.apply() } }
                    }
                }
            }
        }
    }
}
