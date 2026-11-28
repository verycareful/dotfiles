// The station: every workspace as a tile on arms around the dashboard (the hub). The selected tile stays at the
// centre of the screen. Keys: a tile's key goes there, Shift+key merges the current workspace into it, T or A then
// a number for terminals and shots, arrows move along the arms, Ctrl+arrow branches off the selected tile, Home
// selects the hub, Enter goes to the selection (the hub opens the dashboard), Esc closes. Right-drag pans.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import ".."
import "../services"
import "model.js" as Model

Scope {
    id: root
    readonly property int tileW: 320
    readonly property int tileH: 180          // the screen's 16:9
    readonly property int stepX: 400          // cell pitch: a tile plus the gap a link runs through
    readonly property int stepY: 260
    readonly property int panMs: Station.panMs

    property bool prefixShift: false          // the T or A waiting in Station.pendingPrefix was typed with Shift
    property point pan: Qt.point(0, 0)        // right-drag offset, reset when the selection changes

    // Opening: the window maps transparent, takes a picture of the screen, then the picture shrinks into the origin
    // tile (`opened` 0 -> 1) while the wallpaper and the other tiles appear. Leaving: the selected tile grows to the
    // screen (`zoomed` 0 -> 1) and the view unmaps over the real thing.
    property bool armed: false                // the picture is being taken
    property bool ready: false                // the picture exists (or gave up) and the opening has started
    property real opened: 0
    property real zoomed: 0
    readonly property int captureGiveUpMs: 250
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    property string wallCurrent: ""           // the wallpaper `wall` set, else the theme's
    property string wallTheme: ""
    readonly property string wallpaper: wallCurrent !== "" ? wallCurrent : wallTheme
    FileView {
        path: root.stateHome + "/wall/current"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallCurrent = text().trim()
    }
    FileView {
        path: root.stateHome + "/theme/wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallTheme = text().trim()
    }
    function begin() {
        if (ready || !Station.shown) return
        ready = true
        if (Station.fromHub) Panel.setOpen(false)
        openAnim.restart()
    }
    Timer { id: captureWait; interval: root.captureGiveUpMs; onTriggered: root.begin() }
    NumberAnimation { id: openAnim; target: root; property: "opened"; from: 0; to: 1; duration: Station.zoomMs; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: leaveAnim
        PauseAnimation { duration: Station.leaveDelayMs }
        NumberAnimation { target: root; property: "zoomed"; from: 0; to: 1; duration: Station.zoomMs; easing.type: Easing.InOutCubic }
    }

    readonly property var cells: {
        const out = { hub: { col: 0, row: 0, from: null } }
        for (const p of Station.model.positions) out[p.id] = p
        return out
    }
    readonly property var tilesById: {
        const out = {}
        for (const t of Station.model.tiles) out[t.id] = t
        return out
    }
    readonly property var selCell: cells[Station.selected] || cells.hub

    function close() { Station.dismiss() }
    function cellX(c) { return c.col * stepX }
    function cellY(c) { return c.row * stepY }

    function freeSidesOf(id) {
        const t = tilesById[id]
        if (!t || (t.branch !== "terminal" && t.branch !== "app")) return []
        const c = cells[id], used = {}
        for (const k in cells) used[cells[k].col + "," + cells[k].row] = true
        const sides = { right: [1, 0], left: [-1, 0], up: [0, -1], down: [0, 1] }
        return Object.keys(sides).filter(s => !used[(c.col + sides[s][0]) + "," + (c.row + sides[s][1])])
    }
    function branchFrom(id) { Station.leaveTo(id, () => Station.branchSelected()) }
    function activate(id) {
        if (id === "hub") { Station.leaveTo("hub", () => Panel.setOpen(true)); return }
        const t = tilesById[id]
        if (t) Station.goTo(t)
    }
    function send(key, shift) {
        if (shift) Station.merge(key); else Station.jump(key)
    }

    // Shifted digits arrive as their symbols; this maps them back (US layout, the one this machine uses).
    readonly property var shiftedDigits: ({ "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0" })
    function onKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const dirs = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" }
        event.accepted = true
        if (Station.leaving) return
        if (event.key === Qt.Key_Escape) { close(); return }
        if (event.key === Qt.Key_Home) { Station.selected = "hub"; return }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { Station.endMoveHold(); activate(Station.selected); return }
        if (dirs[event.key]) {
            if (ctrl) {
                const t = tilesById[Station.selected]
                if (t && (t.branch === "terminal" || t.branch === "app")) branchFrom(Station.selected)
                return
            }
            const n = Model.neighbour(Station.model.positions, Station.selected || "hub", dirs[event.key])
            if (n) Station.selected = n
            return
        }
        let ch = ""
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) ch = String.fromCharCode(event.key)
        else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) ch = String.fromCharCode(event.key)
        else if (shiftedDigits[event.text] !== undefined) ch = shiftedDigits[event.text]
        if (ch === "") { event.accepted = false; return }
        const digit = ch >= "0" && ch <= "9"
        if (Station.pendingPrefix !== "") {
            const p = Station.pendingPrefix, s = prefixShift
            Station.pendingPrefix = ""
            prefixShift = false
            if (digit) send(p + ch, s)
            return
        }
        if (ch === "T" || ch === "A") { Station.pendingPrefix = ch; prefixShift = shift; return }
        send(ch, shift)
    }

    Connections {
        target: Station
        function onLeavingChanged() { if (Station.leaving) leaveAnim.restart() }
        function onShownChanged() {
            if (!Station.shown) { root.armed = false; root.ready = false; return }
            root.armed = true
            root.ready = false
            root.opened = 0
            root.zoomed = 0
            captureWait.restart()
            root.prefixShift = false
            root.pan = Qt.point(0, 0)
            Station.selected = Station.originId
        }
        function onSelectedChanged() { root.pan = Qt.point(0, 0) }
    }

    PanelWindow {
        id: win
        visible: Station.shown
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: root.ready ? Theme.base : "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-station"
        WlrLayershell.keyboardFocus: Station.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => root.onKey(event)

            Image {
                anchors.fill: parent
                visible: root.ready && status === Image.Ready
                source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(stage.width, stage.height)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point start
                property point panStart
                onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); panStart = root.pan }
                onPositionChanged: mouse => {
                    if (pressedButtons & Qt.RightButton) root.pan = Qt.point(panStart.x + mouse.x - start.x, panStart.y + mouse.y - start.y)
                }
                onClicked: mouse => { if (mouse.button === Qt.LeftButton) root.close() }
            }

            // the screen as it was when the view opened, shrinking into the origin tile
            ScreencopyView {
                id: frozen
                z: 2
                captureSource: root.armed ? win.screen : null
                live: false
                paintCursor: false
                anchors.centerIn: parent
                width: stage.width + (root.tileW - stage.width) * root.opened
                height: stage.height + (root.tileH - stage.height) * root.opened
                visible: root.ready && hasContent && root.opened < 1
                opacity: root.opened < 0.8 ? 1 : (1 - root.opened) / 0.2
                onHasContentChanged: if (hasContent) root.begin()
            }

            Item {
                id: world
                opacity: root.opened
                transform: Scale {
                    origin.x: root.cellX(root.selCell) + root.tileW / 2
                    origin.y: root.cellY(root.selCell) + root.tileH / 2
                    xScale: 1 + (stage.width / root.tileW - 1) * root.zoomed
                    yScale: xScale
                }
                x: stage.width / 2 - root.tileW / 2 - root.cellX(root.selCell) + root.pan.x
                y: stage.height / 2 - root.tileH / 2 - root.cellY(root.selCell) + root.pan.y
                Behavior on x { NumberAnimation { duration: root.panMs; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: root.panMs; easing.type: Easing.OutCubic } }

                // links, centre to centre, under the tiles; dashed into hidden windows
                Repeater {
                    model: Station.model.positions
                    Shape {
                        id: link
                        required property var modelData
                        readonly property var a: root.cells[modelData.from] || root.cells.hub
                        readonly property bool dashed: (root.tilesById[modelData.id] || {}).branch === "hidden"
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Theme.overlay
                            strokeWidth: 2
                            fillColor: "transparent"
                            strokeStyle: link.dashed ? ShapePath.DashLine : ShapePath.SolidLine
                            startX: root.cellX(link.a) + root.tileW / 2
                            startY: root.cellY(link.a) + root.tileH / 2
                            PathLine { x: root.cellX(link.modelData) + root.tileW / 2; y: root.cellY(link.modelData) + root.tileH / 2 }
                        }
                    }
                }

                Tile {
                    x: 0; y: 0; width: root.tileW; height: root.tileH
                    info: null
                    selected: Station.selected === "hub"
                    chrome: 1 - root.zoomed
                    live: Station.shown
                    onClicked: Station.selected === "hub" ? root.activate("hub") : Station.selected = "hub"
                }
                Repeater {
                    model: Station.model.tiles
                    Tile {
                        required property var modelData
                        readonly property var cell: root.cells[modelData.id] || root.cells.hub
                        x: root.cellX(cell); y: root.cellY(cell)
                        width: root.tileW; height: root.tileH
                        info: modelData
                        selected: Station.selected === modelData.id
                        chrome: 1 - root.zoomed
                        live: Station.shown
                        freeSides: root.freeSidesOf(modelData.id)
                        onClicked: Station.selected === modelData.id ? root.activate(modelData.id) : Station.selected = modelData.id
                        onBranchTo: side => root.branchFrom(modelData.id)
                    }
                }
            }
        }
    }
}
