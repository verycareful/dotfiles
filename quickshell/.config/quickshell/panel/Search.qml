// App search: type to filter desktop entries, Enter launches, ↑/↓ move, Esc clears/closes.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."
import "../services"

ColumnLayout {
    id: search
    spacing: 6
    property alias focusItem: input
    property var results: []
    property int selected: 0

    function refresh() {
        const q = input.text.trim().toLowerCase()
        if (q === "") { results = []; selected = 0; return }
        const all = DesktopEntries.applications.values
        const scored = []
        for (const e of all) {
            if (e.noDisplay) continue
            const name = e.name.toLowerCase()
            let s = -1
            if (name.startsWith(q)) s = 0
            else if (name.includes(q)) s = 1
            else if ((e.genericName || "").toLowerCase().includes(q) || (e.keywords || []).some(k => k.toLowerCase().includes(q))) s = 2
            else if ((e.comment || "").toLowerCase().includes(q)) s = 3
            if (s >= 0) scored.push({ e: e, s: s })
        }
        scored.sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name))
        results = scored.slice(0, 8).map(x => x.e)
        selected = 0
    }
    function launch(e) {
        if (!e) return
        e.execute()
        input.text = ""
        Panel.setOpen(false)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.55)
        border.width: 1; border.color: input.activeFocus ? Theme.primaryBright : Theme.overlay
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8
            Text { text: "\u{F0349}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 16 } }   // magnify
            TextInput {
                id: input
                Layout.fillWidth: true
                color: Theme.text
                font { family: Theme.fontUi; pixelSize: 14 }
                clip: true
                onTextChanged: search.refresh()
                Keys.onDownPressed: search.selected = Math.min(search.selected + 1, search.results.length - 1)
                Keys.onUpPressed: search.selected = Math.max(search.selected - 1, 0)
                Keys.onReturnPressed: search.launch(search.results[search.selected])
                Keys.onEscapePressed: { if (text !== "") text = ""; else Panel.setOpen(false) }
                Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: input.text === ""; text: "search apps…"; color: Theme.muted; font: input.font }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        visible: search.results.length > 0
        Repeater {
            model: search.results
            Rectangle {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 34
                color: index === search.selected || rm.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) : "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 10
                    IconImage { implicitSize: 20; source: Quickshell.iconPath(row.modelData.icon, "application-x-executable") }
                    Text { text: row.modelData.name; color: Theme.text; font { family: Theme.fontUi; pixelSize: 13; weight: Font.DemiBold } }
                    Text { Layout.fillWidth: true; text: row.modelData.genericName || row.modelData.comment || ""; color: Theme.muted; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 11 } }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; onClicked: search.launch(row.modelData) }
            }
        }
    }
}
