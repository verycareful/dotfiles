// System tiles: CPU · RAM · GPU · uptime/updates
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

GridLayout {
    columns: 4
    columnSpacing: 8
    rowSpacing: 8
    readonly property var s: Sys.sys

    Stat { glyph: "\u{F0EE0}"; label: "CPU";  value: s.cpu + "%";                       sub: s.tctl + " °C";                       warn: s.tctl >= 85 }   // chip
    Stat { glyph: "\u{F035B}"; label: "RAM";  value: s.memUsed + " GiB";                sub: "of " + s.memTotal + " GiB";          warn: s.memUsed / Math.max(1, s.memTotal) > 0.85 }
    Stat { glyph: "\u{F08AE}"; label: "GPU";  value: s.gpu + "%";                       sub: s.gpuTemp + " °C · " + s.vramUsed + "/" + s.vramTotal + " GiB"; warn: s.gpuTemp >= 85 }
    Stat { glyph: "\u{F0493}"; label: "up";   value: s.uptime;                          sub: s.updates === "" || s.updates === "0" ? "up to date" : s.updates + " updates"; warn: false; accent: s.updates !== "" && s.updates !== "0" }

    component Stat: Widgets.Tile {
        property string glyph
        property string label
        property string value
        property string sub
        property bool warn: false
        property bool accent: false
        Layout.fillWidth: true
        implicitHeight: 62
        ColumnLayout {
            anchors { fill: parent; margins: 8 }
            spacing: 2
            RowLayout {
                spacing: 6
                Text { text: parent.parent.parent.glyph; color: warn ? Theme.red : (accent ? Theme.accent : Theme.muted); font { family: Theme.fontIcon; pixelSize: 14 } }
                Text { text: parent.parent.parent.label; color: Theme.muted; font { family: Theme.fontDisplay; pixelSize: 10; weight: Font.Bold; letterSpacing: 1 } }
            }
            Text { text: parent.parent.value; color: warn ? Theme.red : Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Theme.fontDisplay; pixelSize: 15; weight: Font.Bold } }
            Text { text: parent.parent.sub; color: Theme.subtext; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: 10 } }
        }
    }
}
