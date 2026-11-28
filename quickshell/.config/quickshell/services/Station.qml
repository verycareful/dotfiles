// Station state + IPC (the `station` target). Turns live Hyprland workspaces into the station model (branches,
// keys, layout: station/model.js), routes newly opened windows back to the workspace they were launched from,
// and carries out jumps, merges, moves and branching.
//   qs ipc call station toggle|open|close
//   qs ipc call station prefix T|A         open the view with T or A already typed; the next digit (typed in the view
//                                          or sent as `jump DIGIT`, as SUPER+digit does) picks the number
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
    property string pendingPrefix: ""            // "T" or "A" waiting for its number; cleared whenever the view opens or closes
    property string selected: ""                 // tile id
    property string originId: "hub"              // the dock the screen showed when the view opened: "hub" or a tile id
    property bool fromHub: false                 // the dashboard was up when the view opened; the view closes it once it has a picture of it
    property bool leaving: false                 // the view is zooming into its selection before it closes
    property bool releasing: false               // the zoom is done: the view lets go of the keyboard and fades into the real screen
    readonly property int panMs: 240             // the view's pan to a new selection
    property int leaveDelayMs: 0                 // the pan the zoom waits for when the selection has to change first
    readonly property int zoomMs: 420            // the screen shrinking into a tile, or a tile growing to the screen
    readonly property int fadeMs: 140            // the view fading out over the screen it has zoomed into
    property int holdMs: 0                       // how long the view stays opaque after the zoom: the dashboard needs it to appear first
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
    function padOfKey(key) { return Object.keys(Model.PADS).find(n => Model.PADS[n].key === key) || null }

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

    // Home enters the station-move submap and its release ends it, but the release never arrives while this view
    // holds the keyboard, which would leave every global bind dead. The view therefore ends the hold itself.
    function endMoveHold() { Hyprland.dispatch("hl.dsp.submap(\"reset\")") }

    // Opening the station over the dashboard closes the dashboard: the station holds it as its hub.
    // The dashboard stays up under the opening view until the view has captured it (StationView).
    function setShown(v) {
        pendingPrefix = ""
        endMoveHold()
        leaveTimer.stop()
        fadeTimer.stop()
        actionTimer.stop()
        actionTimer.action = null
        leaving = false
        releasing = false
        if (animationsOff) workspaceAnimations(true)
        if (v) {
            fromHub = Panel.open
            Hyprland.refreshToplevels()
            rebuild()
            originId = originOf(fromHub)
        }
        shown = v
    }

    // Selects `id`, zooms into it, then releases the keyboard and fades the view out over the real screen. Giving the
    // keyboard back hands focus to the window that had it, which would undo a focus change made earlier, so `fn` runs
    // 60 ms after the release, while the view is still fading. With the view closed, `fn` runs at once.
    function leaveTo(id, fn) {
        if (!shown) { if (fn) fn(); return }
        if (leaving) return
        const pans = selected !== id
        selected = id
        pendingPrefix = ""
        endMoveHold()
        leaving = true
        actionTimer.action = fn
        leaveDelayMs = pans ? panMs : 0
        holdMs = id === "hub" ? 200 : 0
        leaveTimer.interval = leaveDelayMs + zoomMs
        leaveTimer.restart()
    }
    // The hub has grown to the whole screen, so the dashboard opens at once instead of rising in.
    function openDashboard() {
        Panel.instant = true
        Panel.setOpen(true)
        Panel.instant = false
    }
    // Backing out grows the origin dock again; for the dashboard that means opening it once more.
    // The station fades between screens itself; Hyprland's slide between workspaces (and over and off a special
    // one) would play on top of it, so it is off from the release until the view is gone.
    property bool animationsOff: false
    function workspaceAnimations(on) {
        animationsOff = !on
        Hyprland.dispatch("function() workspace_animation(" + on + ") end")
    }
    function dismiss() { leaveTo(originId, fromHub ? openDashboard : null) }
    Timer {
        id: leaveTimer
        onTriggered: {
            root.releasing = true
            root.workspaceAnimations(false)
            if (actionTimer.action) actionTimer.restart()
            fadeTimer.restart()
        }
    }
    Timer {
        id: fadeTimer
        interval: root.holdMs + root.fadeMs
        onTriggered: {
            root.shown = false; root.leaving = false; root.releasing = false
            root.workspaceAnimations(true)
        }
    }
    Timer {
        id: actionTimer
        interval: 60
        property var action: null
        onTriggered: { const a = action; action = null; if (a) a() }
    }

    // The dock on screen when the view opens: the hub when the dashboard was up, else the tile holding the focused
    // window (a pad, Hidden or Shots window included), else the tile of the focused workspace.
    function originOf(fromHub) {
        if (fromHub) return "hub"
        const here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : ""
        const a = Hyprland.activeToplevel
        if (a && a.workspace && (a.workspace.name === here || a.workspace.name.startsWith("special:"))) {
            const t = model.tiles.find(x => x.windows.some(w => w.address === a.address))
            if (t) return t.id
        }
        const t = model.tiles.find(x => x.wsName === here && x.branch !== "hidden" && x.branch !== "shot")
        return t ? t.id : "hub"
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

    function classOf(t) { return (t.lastIpcObject || {}).class || (t.wayland ? t.wayland.appId : "") }

    function rebuild() {
        const byWs = {}
        for (const t of Hyprland.toplevels.values) {
            if (!t.workspace) continue
            const ipc = t.lastIpcObject || {}
            const cls = classOf(t)
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
    // `via` says the move came through the station (the view was open) rather than straight from a key: through the
    // station a pad becomes the workspace the user is on; straight from a key it is an overlay.
    function goTo(tile) { const via = shown; leaveTo(tile.id, () => goToNow(tile, via)) }
    function goToNow(tile, via) {
        const w = tile.windows[0]
        if (tile.branch === "pad") {
            padJump(Model.padOfClass(w ? w.cls : null) || tile.wsName.slice("special:".length), via)
            return
        }
        if ((tile.branch === "hidden" || tile.branch === "shot") && tile.wsName.startsWith("special:")) {
            foreground([w])
            return
        }
        focusWorkspace(tile.wsName)
    }

    function freeWorkspace() { return Math.max(0, ...Hyprland.workspaces.values.map(w => w.id)) + 1 }
    // Special workspaces are always overlays, so a window made the user's workspace gets a normal one of its own.
    function foreground(wins) {
        const free = freeWorkspace()
        for (const w of wins) moveWindow(w.address, free, false)
        focusWorkspace(free)
    }
    function padWindows(name) {
        const cls = Model.PADS[name].cls
        return Hyprland.toplevels.values.filter(t => t.workspace && classOf(t) === cls)
    }
    // A pad's windows are either all on its special workspace (overlay) or on a normal one (foreground). Through the
    // station an overlay becomes the foreground; straight from a key a foreground pad you are on opens the station,
    // and one you are not on returns to the overlay.
    function padJump(name, via) {
        if (name === "general") { toggleSpecial("general"); return }
        const special = "special:" + name
        const wins = padWindows(name)
        if (wins.length === 0) {
            const cmd = fixedCommands[Model.PADS[name].key]
            if (cmd) Quickshell.execDetached(["station-launch"].concat(cmd))
            return
        }
        const normal = wins.filter(w => w.workspace.name !== special)
        if (normal.length === 0) { if (via) foreground(wins); else toggleSpecial(name); return }
        const ws = normal[0].workspace.name
        if (via) {
            for (const w of wins) if (w.workspace.name === special) moveWindow(w.address, ws, false)
            focusWorkspace(ws)
            return
        }
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.name === ws) { setShown(true); return }
        for (const w of normal) moveWindow(w.address, special, false)
        toggleSpecial(name)
    }

    function jump(key) {
        const via = shown
        if (pendingPrefix !== "" && /^[0-9]$/.test(key)) key = pendingPrefix + key
        const tile = Model.tileByKey(model, key)
        const pad = padOfKey(key)
        if (pad) { leaveTo(tile ? tile.id : originId, () => padJump(pad, via)); return }
        if (tile) { goTo(tile); return }
        leaveTo(originId, () => { if (fixedCommands[key]) Quickshell.execDetached(["station-launch"].concat(fixedCommands[key])) })
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
        const free = freeWorkspace()
        const e = DesktopEntries.applications.values.find(a => a.name === tile.name)
        if (!e) return
        focusWorkspace(free)
        Quickshell.execDetached(["station-launch", "--ws", String(free)].concat(e.command))
    }

    IpcHandler {
        target: "station"
        function toggle(): void { if (root.shown && !root.leaving) root.dismiss(); else root.setShown(true) }
        function open(): void   { root.setShown(true) }
        function prefix(p: string): void { root.setShown(true); root.pendingPrefix = p }
        function close(): void  { root.dismiss() }
        function jump(key: string): void  { root.jump(key) }
        function merge(key: string): void { root.merge(key) }
        function move(key: string): void  { root.move(key) }
        function branch(): void { root.branchSelected() }
        function launched(pid: int, ws: string): void { root.launches = root.launches.concat([{ pid, ws, at: Date.now() }]) }
        function routes(): string {
            return "launches: " + JSON.stringify(root.launches) + "\nclass routes: " + JSON.stringify([...root.classRoutes])
        }
        function status(): string {
            return "origin " + root.originId + ", selected " + (root.selected || "-") + "\n" + root.model.tiles.map(t => (t.key || "-") + " " + t.branch + " " + t.wsName + " " + t.name + " [" + t.windows.map(w => w.cls).join(",") + "]").join("\n")
        }
    }
}
