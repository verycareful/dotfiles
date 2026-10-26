// Theme window: every theme as a preview card, its dark and light halves side by side. A card shows the theme's
// wallpaper with a small mock desktop drawn in its colours; clicking one (or Enter) runs `theme set`.
// Arrow keys move between cards, Escape closes.
//   qs ipc call themes open|close|toggle   (SUPER+Shift+T, `theme window`)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../panel"

Scope {
    id: root
    property var themes: []          // `theme json`: name, mode, wallpaper and the colour roles of each theme
    property string applying: ""     // theme being set; cleared when Theme.qml reports it
    property int cursor: -1          // keyboard focus, as an index into flat()

    // families in name order, each [dark, light]; a theme without a sibling fills one slot
    function families() {
        const by = {}
        for (const t of themes) {
            const fam = t.name.replace(/-light$/, "")
            by[fam] = by[fam] || [null, null]
            by[fam][t.mode === "light" ? 1 : 0] = t
        }
        return Object.keys(by).sort().map(k => ({ name: k, pair: by[k] }))
    }
    function flat() { return families().reduce((a, f) => a.concat(f.pair.filter(t => t)), []) }
    function apply(name) {
        if (name === Theme.name || applying !== "") return
        applying = name
        Quickshell.execDetached(["theme", "set", name])
    }
    // reads the list first and maps the window after, so it opens at its full size
    function show() { list.running = true }
    function map() {
        if (!win.backingWindowVisible) win.visible = false
        win.visible = true
    }
    Connections { target: Theme; function onNameChanged() { root.applying = "" } }

    Process {
        id: list
        command: ["theme", "json"]
        stdout: StdioCollector { onStreamFinished: { try { root.themes = JSON.parse(text) } catch (e) {} root.map() } }
    }

    IpcHandler {
        target: "themes"
        function open(): void   { root.show() }
        function close(): void  { win.visible = false }
        function toggle(): void { if (win.backingWindowVisible) win.visible = false; else root.show() }
    }

    // `theme set` rewrites Theme.qml and Quickshell reloads the whole shell: keep the window open across it
    PersistentProperties {
        id: keep
        reloadableId: "themeWindow"
        property bool open: false
        onLoaded: if (open) root.show()
    }

    FloatingWindow {
        id: win
        visible: false          // set, not bound: the compositor can close it too
        onClosed: visible = false
        onVisibleChanged: keep.open = visible
        title: "Themes"
        implicitWidth: body.implicitWidth + 36
        implicitHeight: body.implicitHeight + 36
        color: Theme.base

        ColumnLayout {
            id: body
            anchors { left: parent.left; top: parent.top; margins: 18 }
            spacing: 14
            focus: true
            Keys.onEscapePressed: win.visible = false
            Keys.onPressed: e => {
                const all = root.flat(), cols = 2
                const at = root.cursor >= 0 ? root.cursor : Math.max(0, all.findIndex(t => t.name === Theme.name))
                const step = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -cols, [Qt.Key_Down]: cols }[e.key]
                if (step !== undefined) { root.cursor = Math.min(all.length - 1, Math.max(0, at + step)); e.accepted = true }
                else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && all[at]) { root.apply(all[at].name); e.accepted = true }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Themes"; color: Theme.text; font { family: Theme.fontDisplay; pixelSize: 18; weight: Font.Bold; letterSpacing: 1 } }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.applying !== "" ? "Applying " + root.applying + "…" : "Current: " + Theme.name
                    color: root.applying !== "" ? Theme.accent : Theme.subtext
                    font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
                }
            }
            RowLayout {
                spacing: 12
                Item { implicitWidth: 72 }
                Widgets.Heading { text: "DARK"; Layout.preferredWidth: 248 }
                Widgets.Heading { text: "LIGHT"; Layout.preferredWidth: 248 }
            }
            Repeater {
                model: root.families()
                RowLayout {
                    id: row
                    required property var modelData
                    spacing: 12
                    Text {
                        Layout.preferredWidth: 72
                        text: row.modelData.name.charAt(0).toUpperCase() + row.modelData.name.slice(1)
                        color: Theme.subtext
                        font { family: Theme.fontDisplay; pixelSize: 13; weight: Font.Bold }
                    }
                    Repeater {
                        model: row.modelData.pair
                        Card { required property var modelData; theme: modelData }
                    }
                }
            }
            Text {
                text: "Click or Enter applies · arrows move · GTK and Qt apps change on their next start"
                color: Theme.muted
                font { family: Theme.fontUi; pixelSize: 11 }
            }
        }
    }

    // one theme: its wallpaper under a mock bar and window in its colours, the name below
    component Card: Item {
        id: card
        property var theme
        readonly property bool current: theme !== null && theme.name === Theme.name
        readonly property bool focused: theme !== null && root.cursor >= 0 && root.flat()[root.cursor].name === theme.name
        implicitWidth: 248; implicitHeight: 172

        Rectangle {
            visible: card.theme === null
            anchors.fill: parent
            color: "transparent"
            border.width: 1; border.color: Theme.overlay
            Text { anchors.centerIn: parent; text: "none"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 11 } }
        }

        Column {
            visible: card.theme !== null
            spacing: 6
            Rectangle {
                id: frame
                width: card.width; height: 140
                color: card.theme ? "#" + card.theme.base : "transparent"
                border.width: card.current || card.focused || hover.containsMouse ? 2 : 1
                border.color: card.current ? Theme.accent : (card.focused || hover.containsMouse ? Theme.primaryBright : Theme.overlay)
                clip: true
                Image {
                    anchors { fill: parent; margins: frame.border.width }
                    source: card.theme ? "file://" + card.theme.wallpaper : ""
                    sourceSize { width: 496; height: 280 }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Item {
                    id: mock
                    anchors { fill: parent; margins: frame.border.width }
                    visible: card.theme !== null
                    readonly property var t: card.theme || {}
                    function c(k) { return "#" + (t[k] || "000000") }
                    // bar: mantle glass, an accent workspace pill on a primary tint
                    Rectangle {
                        width: parent.width; height: 14
                        color: Qt.alpha(mock.c("mantle"), 0.85)
                        Rectangle { x: 6; y: 4; width: 18; height: 6; color: mock.c("subtext") }
                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 2; width: 34; height: 10; color: Qt.alpha(mock.c("primary"), 0.8)
                                    Rectangle { anchors.centerIn: parent; width: 6; height: 6; color: mock.c("accent") } }
                        Rectangle { anchors.right: parent.right; anchors.rightMargin: 6; y: 4; width: 10; height: 6; color: mock.c("accent") }
                    }
                    // window: base with an accent border, text lines, a selection row and a button
                    Rectangle {
                        x: 18; y: 26; width: parent.width - 36; height: parent.height - 38
                        color: mock.c("base")
                        border.width: 1; border.color: mock.c("accent")
                        Column {
                            x: 10; y: 10; spacing: 6
                            Text { text: "Aa"; color: mock.c("text"); font { family: Theme.fontDisplay; pixelSize: 15; weight: Font.Bold } }
                            Rectangle { width: 120; height: 4; color: mock.c("subtext") }
                            Rectangle { width: 150; height: 12; color: Qt.alpha(mock.c("primary"), 0.8)
                                        Rectangle { x: 4; y: 4; width: 70; height: 4; color: mock.c("text") } }
                            Rectangle { width: 90; height: 4; color: mock.c("muted") }
                        }
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                            width: 44; height: 16; color: mock.c("accent")
                            Rectangle { anchors.centerIn: parent; width: 24; height: 4; color: mock.c("on_accent") }
                        }
                        // the feedback colours, as dots
                        Row {
                            anchors { right: parent.right; top: parent.top; margins: 8 }
                            spacing: 4
                            Repeater { model: ["red", "yellow", "green", "primary_bright"]
                                       Rectangle { required property string modelData; width: 7; height: 7; color: mock.c(modelData) } }
                        }
                    }
                }
                Rectangle {   // dims the card while another theme is being applied
                    anchors.fill: parent
                    visible: root.applying !== "" && root.applying !== (card.theme || {}).name
                    color: Qt.alpha(Theme.base, 0.45)
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.cursor = -1; root.apply(card.theme.name) }
                }
            }
            RowLayout {
                width: card.width
                Text {
                    text: card.theme ? card.theme.name : ""
                    color: card.current ? Theme.accent : Theme.text
                    font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: card.current || root.applying === (card.theme || {}).name
                    text: card.current ? "\u{F012C} current" : "applying…"
                    color: Theme.accent
                    font { family: Theme.fontIcon; pixelSize: 11 }
                }
            }
        }
    }
}
