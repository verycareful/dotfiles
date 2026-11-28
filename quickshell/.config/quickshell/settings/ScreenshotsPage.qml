// Screenshots: whether a shot opens in satty for annotating, whether it notifies, and where shots are saved.
// The settings belong to `shot` (`shot config`), which this page reads on open and writes on every change.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../panel"

ColumnLayout {
    id: page
    spacing: 14
    property var settings: ({ annotate: "on", notify: "on", dir: "" })

    function set(key, value) {
        writer.command = ["shot", "config", key, value]
        writer.running = true
    }

    Process {
        id: reader
        command: ["shot", "config"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) out[line.slice(0, i)] = line.slice(i + 1)
                }
                page.settings = out
                folder.text = out.dir || ""
            }
        }
    }
    Process { id: writer; onExited: reader.running = true }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        SettingRow {
            first: true
            title: "Annotate after capture"
            detail: "Each shot waits under Shots in the station, never over what you are doing. Off: shots are saved at once."
            Widgets.Switch { on: page.settings.annotate === "on"; onClicked: page.set("annotate", page.settings.annotate === "on" ? "off" : "on") }
        }
        SettingRow {
            title: "Show notification"
            detail: "A notification with a preview when a shot is taken."
            Widgets.Switch { on: page.settings.notify === "on"; onClicked: page.set("notify", page.settings.notify === "on" ? "off" : "on") }
        }
        SettingRow {
            title: "Save folder"
            detail: "Press Enter to save the path."
            Rectangle {
                implicitWidth: 360; implicitHeight: 28
                color: Theme.fillField
                border.width: 1; border.color: folder.activeFocus ? Theme.accent : Theme.overlay
                TextInput {
                    id: folder
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.text
                    font { family: Theme.fontUi; pixelSize: 13 }
                    onAccepted: if (text.trim() !== "") page.set("dir", text.trim())
                }
            }
        }
    }
}
