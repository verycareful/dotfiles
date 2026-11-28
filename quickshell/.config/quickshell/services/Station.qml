// Station state + IPC (the `station` target). Turns live Hyprland workspaces into the station model (branches,
// keys, layout: station/model.js), routes newly opened windows back to the workspace they were launched from,
// and carries out jumps, merges, moves and branching.
//   qs ipc call station toggle|open|close
//   qs ipc call station jump KEY            go to the tile with KEY (a fixed key launches its app when absent)
//   qs ipc call station merge KEY           move every window of the current workspace into KEY's, follow
//   qs ipc call station move KEY            move only the focused window into KEY's workspace
//   qs ipc call station branch              Ctrl+arrow / hover arrow on the selected tile
//   qs ipc call station launched PID WS     recorded by station-launch
//   qs ipc call station status|routes      the tiles with their keys; the launch records and class routes
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../station/model.js" as Model

Singleton {
    id: root
    property bool shown: false
    property string selected: ""                 // tile id
    property var model: ({ tiles: [], positions: [] })
    readonly property var book: new Model.KeyBook()

    // Launch records live this long; an app's later windows follow its first one for the same time.
    readonly property int routeTtlMs: 600000
    property var launches: []                    // [{ pid, ws, at }]
    property var classRoutes: new Map()          // class -> { ws, at }
    property var known: ({})                     // window addresses already seen, so only new ones are routed

    // Apps behind the fixed keys, started when the key is pressed and the app is not open.
    readonly property var fixedCommands: ({
        K: ["kern"], S: ["spotify"], D: ["discord"], Z: ["signal-desktop"], B: ["firefox"],
    })
    readonly property var padOfKey: ({ K: "kern", S: "spotify", D: "discord", Z: "signal", G: "general" })

    // Hyprland's Lua config reads a dispatch as a Lua expression (hl.dsp.*), not the classic dispatcher text.
    function q(text) { return JSON.stringify(String(text)) }
    function wsArg(name) { return /^[0-9]+$/.test(String(name)) ? String(name) : q(name) }
    function moveWindow(address, wsName, follow) {
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + wsArg(wsName) + ", follow = " + (follow ? "true" : "false")
            + ", window = \"address:0x" + address + "\" })")
    }
    function focusWindow(address) { Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + address + "\" })") }
    function focusWorkspace(name) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsArg(name) + " })") }
    function toggleSpecial(name) { Hyprland.dispatch("hl.dsp.workspace.toggle_special(" + q(name) + ")") }

    // Opening the station over the dashboard closes the dashboard: the station holds it as its hub.
    function setShown(v) {
        if (v && Panel.open) Panel.setOpen(false)
        if (v) { Hyprland.refreshToplevels(); rebuild() }
        shown = v
    }

    // ── model ─────────────────────────────────────────────────
    property var names: ({})                     // class -> desktop entry name
    function displayName(cls) {
        if (!cls) return ""
        if (names[cls] !== undefined) return names[cls]
        const lc = cls.toLowerCase()
        const e = DesktopEntries.applications.values.find(a =>
            (a.startupClass && a.startupClass.toLowerCase() === lc) || a.id.toLowerCase() === lc)
        names[cls] = e ? e.name : cls
        return names[cls]
    }

    function rebuild() {
        const byWs = {}
        for (const t of Hyprland.toplevels.values) {
            if (!t.workspace) continue
            const ipc = t.lastIpcObject || {}
            const cls = ipc.class || (t.wayland ? t.wayland.appId : "")
            // Special workspaces carry no id, so windows group by workspace name; the name stands in as the id.
            const name = t.workspace.name
            const id = typeof t.workspace.id === "number" && t.workspace.id > 0 ? t.workspace.id : name
            if (!byWs[name]) byWs[name] = { id, name, windows: [] }
            byWs[name].windows.push({ address: t.address, cls, name: displayName(cls), pid: ipc.pid || 0, toplevel: t })
        }
        for (const w of Hyprland.workspaces.values)
            if (!byWs[w.name] && typeof w.id === "number" && w.id > 0) byWs[w.name] = { id: w.id, name: w.name, windows: [] }
        const order = ws => typeof ws.id === "number" ? ws.id : 1e6
        const list = Object.values(byWs).sort((a, b) => order(a) - order(b))
        root.model = Model.buildModel(list, root.book)
        routeNew(list)
    }

    Timer { id: settle; interval: 60; onTriggered: root.rebuild() }
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (["openwindow", "closewindow", "movewindowv2", "createworkspacev2", "destroyworkspacev2",
                 "workspacev2", "activespecial"].includes(e.name)) {
                Hyprland.refreshToplevels()
                Hyprland.refreshWorkspaces()
                settle.restart()
            }
        }
    }
    Component.onCompleted: { Hyprland.refreshToplevels(); settle.restart() }

    // ── launch routing ───────────────────────────────────────
    property var pending: []                     // [{ address, pid, cls, ws }] waiting for their pid chain
    // A window's pid arrives with Hyprland's next client listing, a moment after the window opens; until then it
    // stays unknown and the model is rebuilt again shortly.
    property int pidRetries: 0
    function routeNew(list) {
        const known = {}
        let waiting = false
        for (const ws of list) for (const w of ws.windows) {
            if (root.known[w.address]) { known[w.address] = true; continue }
            if (!w.pid) { waiting = true; continue }
            known[w.address] = true
            pending.push({ address: w.address, pid: w.pid, cls: w.cls, ws: ws.name })
        }
        root.known = known
        if (waiting && pidRetries < 10) { pidRetries++; Hyprland.refreshToplevels(); retry.restart() }
        else pidRetries = 0
        if (!chain.running) nextChain()
    }
    Timer { id: retry; interval: 150; onTriggered: root.rebuild() }
    function nextChain() {
        if (pending.length === 0) return
        chain.item = pending.shift()
        chain.command = ["sh", "-c", "p=$1; while [ \"$p\" -gt 1 ] 2>/dev/null; do echo \"$p\"; p=$(awk '{print $4}' /proc/$p/stat 2>/dev/null); done", "_", String(chain.item.pid)]
        chain.running = true
    }
    Process {
        id: chain
        property var item
        stdout: StdioCollector {
            onStreamFinished: {
                const pids = text.split("\n").filter(l => l.length > 0).map(Number)
                root.route(chain.item, pids)
            }
        }
        onExited: root.nextChain()
    }
    function route(item, pids) {
        // Pads and shots have their own workspaces (rules.lua); routing them would undo that.
        const kind = Model.branchOfClass(item.cls)
        if (kind === "pad" || kind === "shot") return
        const now = Date.now()
        launches = launches.filter(l => now - l.at <= routeTtlMs)
        const target = Model.resolveLaunch(pids, launches, Model.freshClassWs(classRoutes, now, routeTtlMs), item.cls)
        if (target === null) return
        if (!classRoutes.has(item.cls) || launches.some(l => pids.includes(l.pid)))
            classRoutes.set(item.cls, { ws: target, at: now })
        if (target !== item.ws && Hyprland.workspaces.values.some(w => w.name === target))
            moveWindow(item.address, target, false)
    }

    // ── actions ──────────────────────────────────────────────
    function goTo(tile) {
        if (tile.branch === "pad") { toggleSpecial(tile.wsName.slice("special:".length)); return }
        const w = tile.windows[0]
        if (tile.branch === "hidden") {
            moveWindow(w.address, Hyprland.focusedWorkspace.name, false)
            focusWindow(w.address)
            return
        }
        if (tile.branch === "shot") {
            toggleSpecial("shots")
            focusWindow(w.address)
            return
        }
        focusWorkspace(tile.wsName)
    }

    function jump(key) {
        const tile = Model.tileByKey(model, key)
        if (tile) { goTo(tile); return }
        const pad = padOfKey[key]
        if (pad === "general") { toggleSpecial("general"); return }
        if (fixedCommands[key]) Quickshell.execDetached(["station-launch"].concat(fixedCommands[key]))
    }
    function merge(key) {
        const tile = Model.tileByKey(model, key)
        const here = Hyprland.focusedWorkspace
        if (!tile || !here || tile.wsName === here.name) return
        for (const t of Hyprland.toplevels.values)
            if (t.workspace && t.workspace.id === here.id)
                moveWindow(t.address, tile.wsName, false)
        goTo(tile)
    }
    function move(key) {
        const tile = Model.tileByKey(model, key)
        const w = Hyprland.activeToplevel
        if (!tile || !w) return
        moveWindow(w.address, tile.wsName, false)
    }
    // Branching from the selected tile: a terminal tile gets another terminal in its workspace; an app tile gets
    // the app again in a fresh workspace. The arrow's direction only says where the new tile is drawn.
    function branchSelected() {
        const tile = model.tiles.find(t => t.id === selected)
        if (!tile || !tile.windows.length) return
        if (tile.branch === "terminal") {
            Quickshell.execDetached(["station-launch", "--ws", tile.wsName, "kitty"])
            return
        }
        if (tile.branch !== "app") return
        const free = Math.max(0, ...Hyprland.workspaces.values.map(w => w.id)) + 1
        const e = DesktopEntries.applications.values.find(a => a.name === tile.name)
        if (!e) return
        focusWorkspace(free)
        Quickshell.execDetached(["station-launch", "--ws", String(free)].concat(e.command))
    }

    IpcHandler {
        target: "station"
        function toggle(): void { root.setShown(!root.shown) }
        function open(): void   { root.setShown(true) }
        function close(): void  { root.setShown(false) }
        function jump(key: string): void  { root.jump(key) }
        function merge(key: string): void { root.merge(key) }
        function move(key: string): void  { root.move(key) }
        function branch(): void { root.branchSelected() }
        function launched(pid: int, ws: string): void { root.launches = root.launches.concat([{ pid, ws, at: Date.now() }]) }
        function routes(): string {
            return "launches: " + JSON.stringify(root.launches) + "\nclass routes: " + JSON.stringify([...root.classRoutes])
        }
        function status(): string {
            return root.model.tiles.map(t => (t.key || "-") + " " + t.branch + " " + t.wsName + " " + t.name + " [" + t.windows.map(w => w.cls).join(",") + "]").join("\n")
        }
    }
}
