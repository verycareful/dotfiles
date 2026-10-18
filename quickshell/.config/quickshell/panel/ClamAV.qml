// ClamAV: a master switch, every unit with its state and a start/stop switch (system units via pkexec),
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
    readonly property bool scanning: c.scanning === true
    readonly property string notifyTier: "clamav-clamonacc@notify.service"
    // The weekly scan pauses the notify tier for its length; both it and the Notifier are locked meanwhile.
    // The Notifier keeps running: the block tier still scans mid-scan, and it reports those detections.
    function heldByScan(u) { return scanning && (u.unit === notifyTier || u.unit === "clamav-notify.service") }
    readonly property bool allOn: c.units.length > 0 && c.units.every(u => u.active || (scanning && u.unit === notifyTier))
    property string busyUnit: ""   // a unit name, or "*" while the master switch works
    // an interrupted scan still prints "Infected files: 0", so "clean" needs a finished scan
    readonly property bool scanStopped: (c.lastStopped || "") !== "" || c.lastInfected === ""
    readonly property string scanResult: c.lastInfected !== "" && c.lastInfected !== "0"
        ? c.lastInfected + " infected" + (scanStopped ? " (incomplete)" : "")
        : (scanStopped ? "incomplete" : "clean")

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
    // Everything on or everything off, with one pkexec prompt for the system units; the user units follow
    // only if that succeeded. Off also stops clamav-daemon.socket, or the next connection would start clamd
    // again, and a running weekly scan. On leaves the notify tier to a running scan, which restarts it.
    function setAll(on) {
        if (busyUnit !== "") return
        busyUnit = "*"
        const verb = on ? "start" : "stop"
        const sys = c.units.filter(u => u.scope === "system" && !(on && u.unit === notifyTier && scanning)).map(u => u.unit)
        const usr = c.units.filter(u => u.scope === "user").map(u => u.unit)
        if (on) sys.unshift("clamav-daemon.socket")
        else { sys.push("clamav-daemon.socket"); usr.unshift("clamav-weekly-scan.service") }
        Panel.releaseKeyboard = true
        ctl.command = ["bash", "-c", "pkexec systemctl " + verb + " " + sys.join(" ") + " && systemctl --user " + verb + " " + usr.join(" ")]
        ctl.running = true
    }
    function scanNow() {
        if (busyUnit !== "") return
        busyUnit = "clamav-weekly-scan.service"
        ctl.command = ["systemctl", "--user", "start", "--no-block", "clamav-weekly-scan.service"]
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
                RowLayout {
                    spacing: 8
                    Text { text: "ClamAV"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 13; weight: Font.Bold } }
                    Widgets.Switch { on: tile.allOn; enabled: tile.busyUnit === ""; onClicked: tile.setAll(!tile.allOn) }
                    Text { text: "\u{F0341}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 11 } }   // lock: needs auth
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.subtext
                    text: (c.found > 0 ? c.found + " detection(s) since boot" : "No detections since boot")
                        + "  ·  " + (c.lastScan !== "" ? "Weekly scan " + c.lastScan + ": " + tile.scanResult : "No weekly scan yet")
                        + (c.sigs !== "" ? "  ·  Signatures " + c.sigs : "")
                    font { family: Theme.fontUi; pixelSize: 11 }
                }
            }
            ColumnLayout {
                spacing: 4
                Widgets.Button { Layout.fillWidth: true; label: tile.scanning ? "Scanning…" : "Scan now"; enabled: !tile.scanning && tile.busyUnit === ""; onClicked: tile.scanNow() }
                Widgets.Button { Layout.fillWidth: true; label: "Open log"; enabled: c.log !== ""; onClicked: Panel.launch(["kitty", "--title", "clamav log", "-e", "less", "+G", c.log]) }
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
                    readonly property bool busy: tile.busyUnit === modelData.unit || tile.busyUnit === "*"
                    readonly property bool held: tile.heldByScan(modelData)
                    Layout.fillWidth: true
                    implicitHeight: 30
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                    border.width: 1; border.color: Theme.overlay
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                        spacing: 8
                        Rectangle { width: 8; height: 8; color: row.busy ? Theme.yellow : (row.held && !row.modelData.active ? Theme.muted : (row.modelData.active ? Theme.green : Theme.red)) }
                        Text { text: row.modelData.label; color: row.held ? Theme.muted : Theme.text; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
                        Text {
                            Layout.fillWidth: true; color: Theme.muted; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 10 }
                            text: !row.held ? row.modelData.desc : (row.modelData.unit === tile.notifyTier ? "Paused for the weekly scan" : "Locked while the weekly scan runs")
                        }
                        Text { visible: row.modelData.scope === "system"; text: "\u{F0341}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 11 } }   // lock: needs auth
                        Widgets.Switch { on: row.modelData.active; locked: row.held; enabled: !row.busy; onClicked: tile.toggle(row.modelData) }
                    }
                }
            }
        }
    }
}
