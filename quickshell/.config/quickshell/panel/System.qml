// System tiles: CPU · RAM · GPU · uptime/updates
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

GridLayout {
    columns: 4
    columnSpacing: 10
    rowSpacing: 8
    readonly property var s: Sys.sys

    Stat { glyph: "\u{F0EE0}"; label: "CPU";  value: s.cpu + " %";   extra: s.tctl + " °C";    sub: "Load · temperature";                                warn: s.tctl >= 85 }   // chip
    Stat { glyph: "\u{F035B}"; label: "RAM";  value: s.memUsed;      extra: "/ " + s.memTotal + " GiB"; sub: "Used · total";                    warn: s.memUsed / Math.max(1, s.memTotal) > 0.85 }
    Stat { glyph: "\u{F08AE}"; label: "GPU";  value: s.gpu + " %";   extra: s.gpuTemp + " °C"; sub: "VRAM " + s.vramUsed + " / " + s.vramTotal + " GiB"; warn: s.gpuTemp >= 85 }
    Stat { glyph: "\u{F0493}"; label: "Uptime";   value: s.uptime;                          sub: s.updates === "" || s.updates === "0" ? "Up to date" : s.updates + " updates"; warn: false; accent: s.updates !== "" && s.updates !== "0" }

    component Stat: Widgets.Tile {
        property string glyph
        property string label
        property string value
        property string sub
        property string extra: ""
        property bool warn: false
        property bool accent: false
        Layout.fillWidth: true
        implicitHeight: 84
        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 7
            RowLayout {
                spacing: 6
                Text { text: parent.parent.parent.glyph; color: warn ? Theme.red : (accent ? Theme.accent : Theme.muted); font { family: Theme.fontIcon; pixelSize: 14 } }
                Text { text: parent.parent.parent.label; color: Theme.muted; font { family: Theme.fontDisplay; pixelSize: 10; weight: Font.Bold; letterSpacing: 1 } }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text { text: parent.parent.parent.value; color: warn ? Theme.red : Theme.text; font { family: Theme.fontDisplay; pixelSize: 16; weight: Font.Bold } }
                Text { text: parent.parent.parent.extra; visible: text !== ""; color: warn ? Theme.red : Theme.subtext; Layout.alignment: Qt.AlignBaseline; font { family: Theme.fontDisplay; pixelSize: 12; weight: Font.Bold } }
            }
            Text { text: parent.parent.sub; color: Theme.subtext; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: 10 } }
        }
    }
}
