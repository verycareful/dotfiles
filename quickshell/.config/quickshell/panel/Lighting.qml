// OpenRGB presets (profiles in ~/.config/OpenRGB/profiles) through the openrgb.service server, and
// music-reactive lighting (rgb-music.service): on/off, mode, and the palette it draws colours from.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../services"

Widgets.Tile {
    id: tile
    implicitHeight: rows.implicitHeight + 20
    property var profiles: []
    property string current: ""
    property var music: ({ on: false, mode: "pulse", palette: "auto", palettes: [] })
    property string pending: ""

    Process { id: status; command: ["rgb", "status"]; stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); tile.profiles = j.profiles; tile.current = j.current; tile.music = j.music } catch (e) {} } } }
    Process { id: setter; onExited: { tile.pending = ""; status.running = true } }
    Connections { target: Panel; function onOpenChanged() { if (Panel.open) status.running = true } }
    Component.onCompleted: status.running = true
    function run(key, args) { if (pending !== "") return; pending = key; setter.command = ["rgb"].concat(args); setter.running = true }

    ColumnLayout {
        id: rows
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 12 }
        spacing: 8

        RowLayout {
            spacing: 8
            Text { text: "\u{F0335}"; color: tile.current !== "" && tile.current !== "Off" ? Theme.accent : Theme.muted; font { family: Theme.fontIcon; pixelSize: 16 } }   // lightbulb
            Text { text: "Lighting"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12; weight: Font.Bold } }
            Repeater {
                model: tile.profiles
                Chip { required property string modelData; label: modelData; active: modelData === tile.current; busy: tile.pending === "p:" + modelData
                       onClicked: tile.run("p:" + modelData, ["set", modelData]) }
            }
            Text { visible: tile.profiles.length === 0; text: "no profiles, save some in OpenRGB"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 11 } }
            Item { Layout.fillWidth: true }
            Widgets.Button { label: "Open OpenRGB"; onClicked: { Quickshell.execDetached(["openrgb", "--gui", "--client", "localhost:6742", "--noautoconnect"]); Panel.setOpen(false) } }
        }

        RowLayout {
            spacing: 8
            Text { text: "\u{F075A}"; color: tile.music.on ? Theme.accent : Theme.muted; font { family: Theme.fontIcon; pixelSize: 16 } }   // music note
            Chip { label: tile.music.on ? "Music on" : "Music off"; active: tile.music.on; busy: tile.pending === "m"
                   onClicked: tile.run("m", ["music", "toggle"]) }
            Repeater {
                model: [["pulse", "Pulse"], ["spectrum", "Spectrum"], ["colour", "Colour"]]
                Chip { required property var modelData; label: modelData[1]; active: tile.music.mode === modelData[0]; dim: !tile.music.on
                       busy: tile.pending === "mode:" + modelData[0]; onClicked: tile.run("mode:" + modelData[0], ["music", "mode", modelData[0]]) }
            }
            Item { Layout.fillWidth: true }
        }

        Flow {
            visible: tile.music.on
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [["auto", "Cover"], ["theme", "Theme"]]
                Chip { required property var modelData; label: modelData[1]; active: tile.music.palette === modelData[0]
                       busy: tile.pending === "pal:" + modelData[0]; onClicked: tile.run("pal:" + modelData[0], ["music", "palette", modelData[0]]) }
            }
            Repeater {
                model: tile.music.palettes
                Rectangle {
                    id: sw
                    required property var modelData
                    readonly property bool active: tile.music.palette === modelData.name
                    implicitWidth: 24; implicitHeight: 24
                    color: "transparent"
                    border.width: active ? 2 : 1; border.color: active ? Theme.primaryBright : (sm.containsMouse ? Theme.muted : Theme.overlay)
                    Row {
                        anchors { fill: parent; margins: 3 }
                        Repeater {
                            model: sw.modelData.colours
                            Rectangle { required property string modelData; width: parent.width / sw.modelData.colours.length; height: parent.height; color: modelData }
                        }
                    }
                    MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; onClicked: tile.run("pal:" + sw.modelData.name, ["music", "palette", sw.modelData.name]) }
                }
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label
        property bool active: false
        property bool busy: false
        property bool dim: false         // choice that applies once music is on
        signal clicked
        implicitWidth: cl.implicitWidth + 16; implicitHeight: 24
        opacity: dim && !cm.containsMouse ? 0.6 : 1
        color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55) : (cm.containsMouse ? Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9) : "transparent")
        border.width: 1; border.color: active ? Theme.primaryBright : Theme.overlay
        Text { id: cl; anchors.centerIn: parent; text: chip.busy ? "…" : chip.label; color: chip.active ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold } }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
    }
}
