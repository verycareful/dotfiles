// Appearance: the theme (a tile per theme; the theme window has the large previews), following the sun,
// night light and the wallpaper. A theme picked here turns `theme auto` off, as any hand-picked theme does.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../panel"
import "../services"

ColumnLayout {
    id: page
    spacing: 18
    property var themes: []           // `theme json`
    property string auto: ""          // `theme auto status`: "on (06:13 17:39)" or "off"
    readonly property bool autoOn: auto.startsWith("on")
    readonly property var sunTimes: (auto.match(/\((\d\d:\d\d) (\d\d:\d\d)\)/) || []).slice(1)
    readonly property var current: themes.find(t => t.name === Theme.name) || null

    function run(args) { Quickshell.execDetached(["theme"].concat(args)) }
    function setAuto(on) { autoSet.command = ["theme", "auto", on ? "on" : "off"]; autoSet.running = true }

    // dark half before light, family by family
    function ordered(list) {
        const key = t => t.name.replace(/-light$/, "") + (t.mode === "light" ? "1" : "0")
        return list.slice().sort((a, b) => key(a) < key(b) ? -1 : 1)
    }
    Process { running: true; command: ["theme", "json"]
              stdout: StdioCollector { onStreamFinished: { try { page.themes = page.ordered(JSON.parse(text)) } catch (e) {} } } }
    Process { id: autoProbe; running: true; command: ["theme", "auto", "status"]
              stdout: StdioCollector { onStreamFinished: page.auto = text.trim() } }
    Process { id: autoSet; onExited: autoProbe.running = true }

    // ── theme ──
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Widgets.Heading { text: "THEME" }
            Item { Layout.fillWidth: true }
            Widgets.Button { label: "Large previews…"; onClicked: Panel.openWindow("themes") }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 6; columnSpacing: 10; rowSpacing: 10
            Repeater {
                model: page.themes
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool current: modelData.name === Theme.name
                    Layout.fillWidth: true
                    implicitHeight: 96
                    color: "#" + modelData.base
                    border.width: current ? 2 : 1
                    border.color: current ? Theme.accent : (th.containsMouse ? Theme.primaryBright : Theme.overlay)
                    clip: true
                    Image {
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: tile.border.width }
                        height: 66
                        source: "file://" + tile.modelData.wallpaper
                        sourceSize { width: 300; height: 170 }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        Rectangle { width: parent.width; height: 6; color: Qt.alpha("#" + tile.modelData.mantle, 0.9) }
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                            width: 18; height: 6; color: "#" + tile.modelData.accent
                        }
                    }
                    Text {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 7 }
                        text: tile.modelData.name
                        color: "#" + tile.modelData.text
                        font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
                    }
                    MouseArea { id: th; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (!tile.current) page.run(["set", tile.modelData.name]) }
                }
            }
        }
    }

    // ── light and dark, night light, wallpaper ──
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Widgets.Heading { text: "LIGHT AND DARK"; Layout.bottomMargin: 4 }
        SettingRow {
            first: true
            title: "Follow the sun"
            detail: page.sunTimes.length === 2
                    ? "Light from " + page.sunTimes[0] + " to " + page.sunTimes[1] + ", dark otherwise. The place is the weather's (WEATHER_LOC, else found by IP)."
                    : "Light from sunrise to sunset, dark otherwise. Picking a theme by hand turns this off."
            Widgets.Switch { on: page.autoOn; onClicked: page.setAuto(!page.autoOn) }
        }
        SettingRow {
            title: "Right now"
            detail: "Switches to the other half of the current theme and turns Follow the sun off."
            Choice {
                options: ["light", "dark"]
                labels: ["Light", "Dark"]
                value: page.current ? page.current.mode : ""
                onPicked: v => page.run([v])
            }
        }
        SettingRow {
            title: "Night light"
            detail: "A warmer screen (hyprsunset, 4000 K)."
            Widgets.Switch { on: Panel.nightLight; onClicked: Panel.setNightLight(!Panel.nightLight) }
        }
        SettingRow {
            title: "Wallpaper"
            detail: page.current ? page.current.wallpaper.replace(Quickshell.env("HOME"), "~") : ""
            Widgets.Button { label: "Pick…"; onClicked: Panel.runPicker([Quickshell.env("HOME") + "/.local/bin/wall", "pick"], "appearance") }
        }
    }
}
