// CPU thermal limit slider (65–95 °C, 5° steps). Release → pkexec cpu-tctl N (polkit asks once per change).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../services"

Widgets.Tile {
    id: tile
    implicitHeight: 64
    property int current: 85          // from /etc/ryzenadj.conf
    property int pending: current     // while dragging
    property bool busy: false
    property string error: ""
    readonly property int min: 65
    readonly property int max: 95
    readonly property int steps: (max - min) / 5

    FileView {
        id: conf; path: "/etc/ryzenadj.conf"; blockLoading: true; printErrors: false
        onLoaded: { const m = text().match(/--tctl-temp=(\d+)/); if (m) { tile.current = parseInt(m[1]); tile.pending = tile.current } }
    }
    Process {
        id: setter
        stdout: StdioCollector {}
        onExited: (code) => { tile.busy = false; Panel.releaseKeyboard = false; if (code === 0) { tile.current = tile.pending; tile.error = "" } else { tile.pending = tile.current; tile.error = code === 126 || code === 127 ? "cancelled" : "failed (re-run install-ryzenadj.sh?)" } }
    }
    function apply(v) {
        if (v === current || busy) return
        pending = v; busy = true; Panel.releaseKeyboard = true
        setter.command = ["pkexec", "/usr/local/bin/cpu-tctl", String(v)]
        setter.running = true
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 12
        Text { text: "\u{F0E01}"; color: tile.pending >= 95 ? Theme.red : Theme.accent; font { family: Theme.fontIcon; pixelSize: 20 } }   // thermometer
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Text { text: "CPU thermal limit"; color: Theme.text; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: 12; weight: Font.Bold } }
                Text { text: tile.error; visible: tile.error !== ""; color: Theme.red; font { family: Theme.fontUi; pixelSize: 11 } }
                Text { text: tile.busy ? "…" : tile.pending + " °C"; color: tile.pending !== tile.current ? Theme.accent : Theme.subtext; font { family: Theme.fontDisplay; pixelSize: 13; weight: Font.Bold } }
            }
            // slider
            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: 18
                readonly property real stepW: width / tile.steps
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; color: Theme.overlay }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: (tile.pending - tile.min) / (tile.max - tile.min) * parent.width; height: 3; color: tile.pending >= 95 ? Theme.red : Theme.primaryBright }
                Repeater {                        // tick marks
                    model: tile.steps + 1
                    Rectangle { required property int index; x: index * track.stepW - 1; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 7; color: Theme.muted }
                }
                Rectangle {                       // handle
                    x: (tile.pending - tile.min) / (tile.max - tile.min) * track.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    color: tile.busy ? Theme.muted : Theme.accent
                    border.width: 1; border.color: Theme.base
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !tile.busy
                    function valueAt(x) { return tile.min + 5 * Math.round(Math.max(0, Math.min(1, x / track.width)) * tile.steps) }
                    onPressed: mouse => tile.pending = valueAt(mouse.x)
                    onPositionChanged: mouse => { if (pressed) tile.pending = valueAt(mouse.x) }
                    onReleased: tile.apply(tile.pending)
                }
            }
        }
    }
}
