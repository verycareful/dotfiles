// System card: CPU (load, clock, Tctl, thermal-limit slider) · GPU via LACT (load, temps, clocks,
// VRAM, power cap slider + presets, fan) · RAM · uptime · updates.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import ".."
import "../services"

ColumnLayout {
    spacing: 8
    readonly property var s: Sys.sys

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // ── CPU ──────────────────────────────────────────────
        Widgets.Tile {
            Layout.fillWidth: true; Layout.fillHeight: true
            implicitHeight: cpuCol.implicitHeight + 24
            ColumnLayout {
                id: cpuCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8
                Head { glyph: "\u{F0EE0}"; label: "CPU"; name: "Ryzen 9 7900X" }
                Meter { value: s.cpu; big: s.cpu + " %"; note: s.ghz + " GHz"; hot: s.tctl >= 85 }
                Line  { items: [[s.tctl + " °C", "Tctl"], [PowerProfiles.profile === PowerProfile.Performance ? "Performance" : (PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : "Balanced"), "profile"]] }
                Thermal { Layout.fillWidth: true; Layout.topMargin: 2 }
                Line  { items: [["12 c / 24 t", ""], ["Zen 4", ""]] }
            }
        }

        // ── GPU ──────────────────────────────────────────────
        Widgets.Tile {
            Layout.fillWidth: true; Layout.fillHeight: true
            implicitHeight: gpuCol.implicitHeight + 24
            ColumnLayout {
                id: gpuCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8
                Head { glyph: "\u{F08AE}"; label: "GPU"; name: Gpu.name !== "" ? Gpu.name : "Radeon"
                       action: Widgets.Button { label: "Open LACT"; onClicked: { Quickshell.execDetached(["lact", "gui"]); Panel.setOpen(false) } } }
                Meter { value: Gpu.busyPct; big: Math.round(Gpu.busyPct) + " %"; note: Gpu.clock + " MHz"; hot: Gpu.tempJunc >= 95 }
                Line  { items: [[Math.round(Gpu.tempEdge) + " °C", "edge"], [Math.round(Gpu.tempJunc) + " °C", "junction"], [Math.round(Gpu.tempMem) + " °C", "memory"]]; hot: Gpu.tempJunc >= 95 }
                Meter { value: Gpu.vramTotal > 0 ? Gpu.vramUsed / Gpu.vramTotal * 100 : 0; big: Gpu.vramUsed.toFixed(1) + " GiB"; note: "of " + Math.round(Gpu.vramTotal) + " GiB VRAM · " + Gpu.vclock + " MHz"; small: true }
                PowerCap { Layout.fillWidth: true }
                Line  { items: [[Gpu.fanPct + " %", "fan"], [Gpu.fanRpm + " rpm", ""]] }
            }
        }
    }

    // ── RAM · uptime · updates ───────────────────────────────
    Widgets.Tile {
        Layout.fillWidth: true
        implicitHeight: 46
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 18
            Text { text: "\u{F035B}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 14 } }
            Meter { Layout.fillWidth: true; value: s.memTotal > 0 ? s.memUsed / s.memTotal * 100 : 0; big: s.memUsed + " GiB"; note: "of " + s.memTotal + " GiB RAM"; small: true; hot: s.memUsed / Math.max(1, s.memTotal) > 0.85 }
            Line  { items: [[s.uptime, "uptime"]] }
            Line  { items: [[s.updates === "" || s.updates === "0" ? "Up to date" : s.updates + " updates", ""]]; accent: s.updates !== "" && s.updates !== "0" }
        }
    }

    // ── pieces ───────────────────────────────────────────────
    component Head: RowLayout {
        property string glyph
        property string label
        property string name
        property Component action: null
        Layout.fillWidth: true
        spacing: 8
        Text { text: parent.glyph; color: Theme.accent; font { family: Theme.fontIcon; pixelSize: 15 } }
        Text { text: parent.label; color: Theme.muted; font { family: Theme.fontDisplay; pixelSize: 11; weight: Font.Bold; letterSpacing: 1.5 } }
        Text { Layout.fillWidth: true; text: parent.name; color: Theme.subtext; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 11 } }
        Loader { sourceComponent: parent.action }
    }
    component Meter: ColumnLayout {          // big number + right text over a bar
        property real value: 0
        property string big
        property string note
        property bool hot: false
        property bool small: false
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Text { text: parent.parent.big; color: parent.parent.hot ? Theme.red : Theme.text; font { family: Theme.fontDisplay; pixelSize: parent.parent.small ? 13 : 20; weight: Font.Bold } }
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: parent.parent.note; color: Theme.subtext; elide: Text.ElideLeft; font { family: Theme.fontUi; pixelSize: 11 } }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 4; color: Theme.overlay
            Rectangle { width: Math.max(0, Math.min(1, parent.parent.value / 100)) * parent.width; height: parent.height; color: parent.parent.hot ? Theme.red : (parent.parent.value >= 85 ? Theme.yellow : Theme.primaryBright); Behavior on width { NumberAnimation { duration: 300 } } }
        }
    }
    component Line: RowLayout {              // "61 °C Tctl · 4.6 GHz avg" style row
        property var items: []
        property bool hot: false
        property bool accent: false
        spacing: 14
        Repeater {
            model: parent.items
            RowLayout {
                required property var modelData
                spacing: 4
                Text { text: parent.modelData[0]; color: hot ? Theme.red : (accent ? Theme.accent : Theme.text); font { family: Theme.fontDisplay; pixelSize: 12; weight: Font.Bold } }
                Text { visible: text !== ""; text: parent.modelData[1]; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
            }
        }
    }
}
