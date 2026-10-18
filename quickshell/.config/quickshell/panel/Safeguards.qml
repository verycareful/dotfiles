// Safeguards: system snapshots (snapper), the firewall (ufw), the home backup (restic). One row per safeguard, each with its state and actions.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../services"

Widgets.Tile {
    id: tile
    implicitHeight: col.implicitHeight + 20
    readonly property var s: Sys.safe
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    property bool busy: false

    Process {
        id: act
        onExited: { tile.busy = false; Panel.releaseKeyboard = false; Sys.refreshSafe() }
    }
    function run(cmd, auth) {
        if (busy) return
        busy = true
        if (auth) Panel.releaseKeyboard = true   // the polkit dialog needs the keys
        act.command = cmd
        act.running = true
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 10

        Guard {
            id: snapRow
            readonly property var v: tile.s.snap || {}
            glyph: "\u{F0BD5}"   // camera-burst
            tint: !v.available ? Theme.red : (v.timeline ? Theme.green : Theme.yellow)
            title: "Snapshots"
            detail: !v.available ? "Not set up: sudo ./snapper/install-snapper.sh"
                : v.count + " of /" + (v.last !== "" ? "  ·  last " + v.last + " (" + v.lastDesc + ")" : "")
                  + (v.timeline ? "  ·  hourly" : "  ·  timeline off")
            Widgets.Button { label: "Snapshot now"; enabled: !tile.busy && snapRow.v.available === true; onClicked: tile.run([tile.bin + "snap", "now", "panel"]) }
            Widgets.Button { label: "Browse"; onClicked: { Panel.launch([tile.bin + "snap", "gui"]); Panel.setOpen(false) } }
        }

        Guard {
            id: fwRow
            readonly property var v: tile.s.fw || {}
            glyph: v.on ? "\u{F0565}" : "\u{F099D}"   // shield-check / shield-off
            tint: !v.installed ? Theme.red : (v.on ? Theme.green : Theme.red)
            title: "Firewall"
            detail: !v.installed ? "Not set up: sudo ./firewall/install-firewall.sh"
                : (v.on ? "Inbound blocked" : "Off: every port is open")
                  + "  ·  " + v.rules + " allow rule" + (v.rules === 1 ? "" : "s")
                  + "  ·  " + v.blocked + " blocked this boot"
            Widgets.Switch { on: fwRow.v.on === true; enabled: !tile.busy && fwRow.v.installed === true; onClicked: tile.run([tile.bin + "fw", fwRow.v.on ? "off" : "on"], true) }
            Text { text: "\u{F0341}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 11 } }   // lock: needs auth
            Widgets.Button { label: "Log"; onClicked: { Panel.launch(["kitty", "--title", "firewall log", "-e", "bash", "-c", tile.bin + "fw log | less +G"]); Panel.setOpen(false) } }
        }

        Guard {
            id: bkRow
            readonly property var v: tile.s.backup || {}
            // added bytes from the last run, as a short size
            function size(b) { return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GiB" : b >= 1048576 ? Math.round(b / 1048576) + " MiB" : Math.round(b / 1024) + " KiB" }
            glyph: "\u{F006F}"   // backup-restore
            tint: !v.setup ? Theme.red : (v.running ? Theme.accent : (v.result === "ok" ? Theme.green : Theme.yellow))
            title: "Backup"
            detail: !v.setup ? "Not set up: sudo ./backup/install-backup.sh LABEL=..., then backup init"
                : (v.running ? "Backing up…" : (v.last !== "" ? "Last " + v.last + (v.result === "ok" ? " (+" + size(v.added) + ")" : "") : "No backup yet"))
                  + (v.result !== "ok" && v.result !== "" && !v.running ? "  ·  " + v.result : "")
                  + (v.drive ? "" : "  ·  drive absent")
            Widgets.Button {
                label: "Back up now"
                enabled: !tile.busy && bkRow.v.setup === true && bkRow.v.drive === true && bkRow.v.running !== true
                onClicked: tile.run(["systemctl", "--user", "start", "--no-block", "backup.service"])
            }
        }
    }
}
