// Full-width song visualiser: cava's bars drawn edge to edge under Waybar. In this mode the layer paints the bar's
// glass itself and Waybar goes transparent (Panel.barCss), so the bars stay sharp behind the modules. cava runs only
// while a player is playing. Mode: Panel.vizMode (qs ipc call panel viz, SUPER+Shift+V).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import ".."
import "../services"

Scope {
    id: root
    readonly property int barHeight: 36     // waybar config.jsonc "height"
    readonly property int maxLevel: 1000    // cava.conf ascii_max_range
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying && !(p.dbusName || "").includes("playerctld"))
    readonly property bool shown: Panel.vizMode === "full"
    readonly property bool active: shown && playing
    property var levels: []

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellPath("viz/cava.conf")]
        stdout: SplitParser { onRead: line => root.levels = line.split(";").filter(s => s !== "").map(Number) }
        onRunningChanged: if (!running) root.levels = []
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.shown
            anchors { top: true; left: true; right: true }
            implicitHeight: root.barHeight
            exclusionMode: ExclusionMode.Ignore    // under the bar, not pushed below its exclusive zone
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Bottom   // beneath Waybar (top layer), above the wallpaper
            WlrLayershell.namespace: "qs-viz"
            mask: Region {}

            Rectangle { anchors.fill: parent; color: Theme.glassBar }

            Row {
                id: row
                anchors.fill: parent
                readonly property real slot: width / Math.max(1, root.levels.length)
                Repeater {
                    model: root.levels.length
                    Item {
                        required property int index
                        width: row.slot; height: row.height
                        Rectangle {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            width: Math.max(1, row.slot * 0.45)
                            height: row.height * Math.min(1, (root.levels[index] || 0) / root.maxLevel)
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }
}
