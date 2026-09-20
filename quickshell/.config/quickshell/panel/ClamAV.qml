// ClamAV: on-access tiers, detections this boot, last weekly scan; scan now / open log.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"

Widgets.Tile {
    implicitHeight: 74
    readonly property var c: Sys.clam
    readonly property bool ok: c.block === "active" && c.notify === "active" && c.daemon === "active"

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
        spacing: 12
        Text { text: ok ? "\u{F0483}" : "\u{F0498}"; color: ok ? (c.found > 0 ? Theme.yellow : Theme.green) : Theme.red; font { family: Theme.fontIcon; pixelSize: 26 } }   // shield-check / shield-alert
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                spacing: 10
                Text { text: "ClamAV"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12; weight: Font.Bold } }
                Dot { label: "block";  on: c.block === "active" }
                Dot { label: "notify"; on: c.notify === "active" }
                Dot { label: "clamd";  on: c.daemon === "active" }
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Theme.subtext
                text: (c.found > 0 ? c.found + " detection(s) since boot · " : "no detections since boot · ")
                    + (c.lastScan !== "" ? "weekly scan " + c.lastScan + ": " + (c.lastInfected === "0" ? "clean" : c.lastInfected + " infected") : "no weekly scan yet")
                    + (c.sigs !== "" ? "\nsignatures " + c.sigs : "")
                font { family: Theme.fontUi; pixelSize: 11 }
            }
        }
        ColumnLayout {
            spacing: 4
            Widgets.Button { label: "scan now"; onClicked: Quickshell.execDetached(["kitty", "--title", "clamav weekly scan", "-e", "bash", "-c", "~/.local/bin/clamav-weekly-scan.sh; read -rp 'done — enter to close'"]) }
            Widgets.Button { label: "open log"; enabled: c.log !== ""; onClicked: Quickshell.execDetached(["kitty", "--title", "clamav log", "-e", "less", "+G", c.log]) }
        }
    }
    component Dot: RowLayout {
        property string label
        property bool on
        spacing: 4
        Rectangle { width: 7; height: 7; color: on ? Theme.green : Theme.red }
        Text { text: parent.label; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
    }
}
