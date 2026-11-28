// All apps: every desktop entry by name under letter headers, in balanced columns, an A-Z rail on the left
// (letters with no apps greyed). Typing filters; Up/Down move the highlight, Enter opens it, Esc clears the
// filter and then closes the dashboard. apps-exclude.txt lists the entries left out.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."
import "../services"
import "../panel"
import "reveal.js" as Reveal

Item {
    id: view
    signal back
    property real reveal: 1                         // 0..1, set by Dashboard (reveal.js)
    property alias focusItem: input

    readonly property int marginX: 64
    readonly property int marginY: 40
    readonly property int filterWidth: 420
    readonly property int colMinWidth: 340
    readonly property int colGap: 28
    readonly property int railWidth: 30
    readonly property int headerH: 30
    readonly property int rowH: 34
    readonly property int groupGap: 12
    readonly property var letters: ["#"].concat("ABCDEFGHIJKLMNOPQRSTUVWXYZ".split(""))

    // ── entries ──────────────────────────────────────────────
    FileView { id: excludeFile; path: Qt.resolvedUrl("apps-exclude.txt").toString().replace("file://", ""); blockLoading: true; printErrors: false }
    readonly property var excludes: excludeFile.text().split("\n").map(l => l.trim()).filter(l => l !== "" && !l.startsWith("#"))
        .map(p => new RegExp("^" + p.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*") + "$"))

    function letterOf(e) { const c = e.name.charAt(0).toUpperCase(); return c >= "A" && c <= "Z" ? c : "#" }
    readonly property var apps: {
        const seen = {}, out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay || seen[e.id] || excludes.some(re => re.test(e.id))) continue
            seen[e.id] = true
            out.push(e)
        }
        return out.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
    }
    readonly property var shown: {
        const q = input.text.trim().toLowerCase()
        if (q === "") return apps
        return apps.filter(e => e.name.toLowerCase().includes(q) || (e.genericName || "").toLowerCase().includes(q)
                               || (e.keywords || []).some(k => k.toLowerCase().includes(q)))
    }
    property int selected: 0
    onShownChanged: selected = 0

    // groups by letter, each app with its index in `shown`, dealt into columns of about equal height
    readonly property int nCols: Math.max(1, Math.floor((width - 2 * marginX - railWidth - colGap + colGap) / (colMinWidth + colGap)))
    readonly property var columns: {
        const groups = []
        shown.forEach((e, i) => {
            const l = letterOf(e)
            if (groups.length === 0 || groups[groups.length - 1].letter !== l) groups.push({ letter: l, items: [] })
            groups[groups.length - 1].items.push({ e: e, i: i })
        })
        const h = g => headerH + g.items.length * rowH + groupGap
        const total = groups.reduce((s, g) => s + h(g), 0)
        const target = total / nCols
        const cols = [[]]
        let cur = 0
        for (const g of groups) {
            if (cur > 0 && cur + h(g) / 2 > target && cols.length < nCols) { cols.push([]); cur = 0 }
            cols[cols.length - 1].push(g)
            cur += h(g)
        }
        return cols
    }
    readonly property var present: {
        const p = {}
        for (const e of shown) p[letterOf(e)] = true
        return p
    }

    function launch(e) {
        if (!e) return
        Panel.launchApp(e.command)
        input.text = ""
        Panel.setOpen(false)
    }
    function jump(letter) {
        const i = shown.findIndex(e => letterOf(e) === letter)
        if (i >= 0) selected = i
    }
    Connections { target: Panel; function onOpenChanged() { if (Panel.open) input.text = "" } }

    MouseArea { anchors.fill: parent; z: -1; onClicked: Panel.setOpen(false) }

    // ── header: back, title, filter ──────────────────────────
    RowLayout {
        id: header
        opacity: Reveal.stage(view.reveal, 0); transform: Translate { y: Reveal.offset(view.reveal, 0) }
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: view.marginX; rightMargin: view.marginX; topMargin: view.marginY }
        spacing: 14
        Rectangle {
            implicitWidth: backRow.implicitWidth + 20; implicitHeight: 30
            color: bm.containsMouse ? Theme.glassCard : "transparent"
            border.width: 1; border.color: bm.containsMouse ? Theme.overlay : "transparent"
            Row {
                id: backRow
                anchors.centerIn: parent
                spacing: 8
                Glyph { text: "\u{F0143}"; color: Theme.subtext; size: 14 }          // chevron-up
                Text { text: "Dashboard  ·  Tab"; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
            }
            MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; onClicked: view.back() }
        }
        Text { text: "All apps"; color: Theme.text; font { family: Theme.fontDisplay; pixelSize: 22; weight: Font.Bold } }
        Text {
            Layout.fillWidth: true
            text: view.shown.length === view.apps.length ? view.apps.length + ", by name" : view.shown.length + " of " + view.apps.length
            color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 13; weight: Font.DemiBold }
        }
        Rectangle {
            implicitWidth: view.filterWidth; implicitHeight: 36
            color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.55)
            border.width: 1; border.color: input.activeFocus ? Theme.primaryBright : Theme.overlay
            MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8
                Glyph { text: "\u{F0349}"; color: Theme.muted; size: 16 }   // magnify
                TextInput {
                    id: input
                    Layout.fillWidth: true
                    color: Theme.text
                    font { family: Theme.fontUi; pixelSize: 14 }
                    clip: true
                    Keys.onDownPressed: view.selected = Math.min(view.selected + 1, view.shown.length - 1)
                    Keys.onUpPressed: view.selected = Math.max(view.selected - 1, 0)
                    Keys.onReturnPressed: view.launch(view.shown[view.selected])
                    Keys.onEnterPressed: view.launch(view.shown[view.selected])
                    Keys.onEscapePressed: { if (text !== "") text = ""; else Panel.setOpen(false) }
                    Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: input.text === ""; text: "Filter apps…"; color: Theme.muted; font: input.font }
                }
            }
        }
    }

    // ── rail + columns ───────────────────────────────────────
    RowLayout {
        opacity: Reveal.stage(view.reveal, 1); transform: Translate { y: Reveal.offset(view.reveal, 1) }
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom
                  leftMargin: view.marginX; rightMargin: view.marginX; topMargin: 24; bottomMargin: view.marginY }
        spacing: view.colGap

        Column {
            Layout.alignment: Qt.AlignTop
            spacing: 1
            Repeater {
                model: view.letters
                Rectangle {
                    required property string modelData
                    readonly property bool has: view.present[modelData] === true
                    width: view.railWidth; height: 21
                    color: has && rm.containsMouse ? Theme.accent : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: !parent.has ? Theme.muted : (rm.containsMouse ? Theme.textOnAccent : Theme.text)
                        font { family: Theme.fontDisplay; pixelSize: 12 }
                    }
                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: parent.has; onClicked: if (parent.has) view.jump(parent.modelData) }
                }
            }
        }

        Row {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            clip: true
            spacing: view.colGap
            readonly property real colWidth: (width - (view.nCols - 1) * spacing) / view.nCols
            Repeater {
                model: view.columns
                Column {
                    id: column
                    required property var modelData
                    width: parent.colWidth
                    Repeater {
                        model: column.modelData
                        Column {
                            id: group
                            required property var modelData
                            width: column.width
                            bottomPadding: view.groupGap
                            Item {
                                width: parent.width; height: view.headerH
                                Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; text: group.modelData.letter; color: Theme.accent; font { family: Theme.fontDisplay; pixelSize: 14 } }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.overlay }
                            }
                            Repeater {
                                model: group.modelData.items
                                AppRow { required property var modelData; width: group.width; entry: modelData.e; index: modelData.i }
                            }
                        }
                    }
                }
            }
        }
    }

    component AppRow: Rectangle {
        id: row
        property var entry
        property int index
        readonly property string icon: Quickshell.iconPath(entry.icon, true)
        height: view.rowH
        color: index === view.selected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
             : (am.containsMouse ? Theme.glassCard : "transparent")
        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
            spacing: 10
            Item {
                implicitWidth: 24; implicitHeight: 24
                IconImage { anchors.fill: parent; visible: row.icon !== ""; source: row.icon }
                Rectangle {
                    anchors.fill: parent; visible: row.icon === ""; color: Theme.overlay
                    Text { anchors.centerIn: parent; text: row.entry.name.charAt(0).toUpperCase(); color: Theme.subtext; font { family: Theme.fontDisplay; pixelSize: 11 } }
                }
            }
            Text { Layout.fillWidth: true; text: row.entry.name; color: Theme.text; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 13; weight: Font.DemiBold } }
        }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: view.launch(row.entry) }
    }
}
