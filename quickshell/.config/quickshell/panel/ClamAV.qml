// ClamAV: every unit with its state and a start/stop switch (system units via pkexec),
// detections this boot, last weekly scan, signature date; scan now / open log.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../services"

Widgets.Tile {
    id: tile
    implicitHeight: col.implicitHeight + 20
    readonly property var c: Sys.clam
    readonly property bool allOn: c.units.length > 0 && c.units.every(u => u.active)
    property string busyUnit: ""

    Process {
        id: ctl
        stdout: StdioCollector {}
        onExited: (code) => { tile.busyUnit = ""; Panel.releaseKeyboard = false; Sys.refreshClam() }
    }
    function toggle(u) {
        if (busyUnit !== "") return
        busyUnit = u.unit
        const verb = u.active ? "stop" : "start"
        if (u.scope === "user") ctl.command = ["systemctl", "--user", verb, u.unit]
        else { Panel.releaseKeyboard = true; ctl.command = ["pkexec", "systemctl", verb, u.unit] }
        ctl.running = true
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text { text: allOn ? "\u{F0483}" : "\u{F0498}"; color: allOn ? (c.found > 0 ? Theme.yellow : Theme.green) : Theme.red; font { family: Theme.fontIcon; pixelSize: 28 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "ClamAV"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 13; weight: Font.Bold } }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.subtext
                    text: (c.found > 0 ? c.found + " detection(s) since boot" : "No detections since boot")
                        + "  ·  " + (c.lastScan !== "" ? "Weekly scan " + c.lastScan + ": " + (c.lastInfected === "0" ? "clean" : c.lastInfected + " infected") : "No weekly scan yet")
                        + (c.sigs !== "" ? "  ·  Signatures " + c.sigs : "")
                    font { family: Theme.fontUi; pixelSize: 11 }
                }
            }
            ColumnLayout {
                spacing: 4
                Widgets.Button { Layout.fillWidth: true; label: "Scan now"; onClicked: Quickshell.execDetached(["kitty", "--title", "clamav weekly scan", "-e", "bash", "-c", "~/.local/bin/clamav-weekly-scan.sh; read -rp 'done — enter to close'"]) }
                Widgets.Button { Layout.fillWidth: true; label: "Open log"; enabled: c.log !== ""; onClicked: Quickshell.execDetached(["kitty", "--title", "clamav log", "-e", "less", "+G", c.log]) }
            }
        }
        // units, two columns
        GridLayout {
            Layout.fillWidth: true
            columns: 2; columnSpacing: 8; rowSpacing: 4
            Repeater {
                model: tile.c.units
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool busy: tile.busyUnit === modelData.unit
                    Layout.fillWidth: true
                    implicitHeight: 30
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                    border.width: 1; border.color: Theme.overlay
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                        spacing: 8
                        Rectangle { width: 8; height: 8; color: row.busy ? Theme.yellow : (row.modelData.active ? Theme.green : Theme.red) }
                        Text { text: row.modelData.label; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
                        Text { Layout.fillWidth: true; text: row.modelData.desc; color: Theme.muted; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 10 } }
                        Text { visible: row.modelData.scope === "system"; text: "\u{F0341}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 11 } }   // lock: needs auth
                        Rectangle {                                                   // switch
                            implicitWidth: 30; implicitHeight: 16
                            color: row.modelData.active ? Theme.primary : Theme.overlay
                            border.width: 1; border.color: row.modelData.active ? Theme.primaryBright : Theme.muted
                            Rectangle { width: 10; height: 10; y: 3; x: row.modelData.active ? parent.width - width - 3 : 3; color: row.modelData.active ? Theme.accent : Theme.subtext; Behavior on x { NumberAnimation { duration: 120 } } }
                            MouseArea { anchors.fill: parent; enabled: !row.busy; onClicked: tile.toggle(row.modelData) }
                        }
                    }
                }
            }
        }
    }
}
