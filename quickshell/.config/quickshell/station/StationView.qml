// The station: every workspace as a tile on arms around the dashboard (the hub). The selected tile stays at the
// centre of the screen. Keys: a tile's key goes there, Shift+key merges the current workspace into it, T or A then
// a number for terminals and shots, arrows move along the arms, Ctrl+arrow branches off the selected tile, Home
// selects the hub, Enter goes to the selection (the hub opens the dashboard), Esc closes. Right-drag pans.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../services"
import "model.js" as Model

Scope {
    id: root
    readonly property int tileW: 320
    readonly property int tileH: 180          // the screen's 16:9
    readonly property int stepX: 400          // cell pitch: a tile plus the gap a link runs through
    readonly property int stepY: 260
    readonly property int panMs: 180

    property bool prefixShift: false          // the T or A waiting in Station.pendingPrefix was typed with Shift
    property point pan: Qt.point(0, 0)        // right-drag offset, reset when the selection changes

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

    function close() { Station.setShown(false) }
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
    function branchFrom(id) {
        Station.selected = id
        Station.branchSelected()
        close()
    }
    function activate(id) {
        if (id === "hub") { close(); Panel.setOpen(true); return }
        const t = tilesById[id]
        if (t) { Station.goTo(t); close() }
    }
    function send(key, shift) {
        if (shift) Station.merge(key); else Station.jump(key)
        close()
    }

    // Shifted digits arrive as their symbols; this maps them back (US layout, the one this machine uses).
    readonly property var shiftedDigits: ({ "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0" })
    function onKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const dirs = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" }
        event.accepted = true
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
        function onShownChanged() {
            if (!Station.shown) return
            root.prefixShift = false
            root.pan = Qt.point(0, 0)
            const here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : ""
            const t = Station.model.tiles.find(x => x.wsName === here && x.branch !== "hidden" && x.branch !== "shot")
            Station.selected = t ? t.id : "hub"
        }
        function onSelectedChanged() { root.pan = Qt.point(0, 0) }
    }

    PanelWindow {
        visible: Station.shown
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.scrim
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-station"
        WlrLayershell.keyboardFocus: Station.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => root.onKey(event)

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

            Item {
                id: world
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
