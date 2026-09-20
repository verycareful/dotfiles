// OpenRGB presets (profiles in ~/.config/OpenRGB/profiles) through the openrgb.service server.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../services"

Widgets.Tile {
    id: tile
    implicitHeight: 44
    property var profiles: []
    property string current: ""
    property string pending: ""

    Process { id: status; command: ["rgb", "status"]; stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); tile.profiles = j.profiles; tile.current = j.current } catch (e) {} } } }
    Process { id: setter; onExited: { tile.pending = ""; status.running = true } }
    Connections { target: Panel; function onOpenChanged() { if (Panel.open) status.running = true } }
    Component.onCompleted: status.running = true
    function apply(name) { if (pending !== "") return; pending = name; setter.command = ["rgb", "set", name]; setter.running = true }

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
        spacing: 8
        Text { text: "\u{F0335}"; color: tile.current !== "" && tile.current !== "Off all" ? Theme.accent : Theme.muted; font { family: Theme.fontIcon; pixelSize: 16 } }   // lightbulb
        Text { text: "Lighting"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12; weight: Font.Bold } }
        Repeater {
            model: tile.profiles
            Rectangle {
                required property string modelData
                readonly property bool active: modelData === tile.current
                readonly property bool busy: modelData === tile.pending
                implicitWidth: pl.implicitWidth + 16; implicitHeight: 24
                color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55) : (pm.containsMouse ? Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9) : "transparent")
                border.width: 1; border.color: active ? Theme.primaryBright : Theme.overlay
                Text { id: pl; anchors.centerIn: parent; text: parent.busy ? "…" : parent.modelData; color: parent.active ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold } }
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: tile.apply(parent.modelData) }
            }
        }
        Text { visible: tile.profiles.length === 0; text: "no profiles — save some in OpenRGB"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 11 } }
        Item { Layout.fillWidth: true }
        Widgets.Button { label: "Open OpenRGB"; onClicked: { Quickshell.execDetached(["openrgb", "--client", "localhost:6742"]); Panel.setOpen(false) } }
    }
}
