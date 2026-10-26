// Widget panel state + IPC. Only one of panel / notification centre is open at a time.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    property bool releaseKeyboard: false   // true while a polkit dialog is up, so it gets the keys
    property bool mediaOnBar: true          // "Media on bar" toggle → waybar state.css
    // song visualiser: off, compact (custom/viz beside the song), wide (custom/viz#wide in the centre, workspaces
    // move left) or full (BarViz under the whole bar)
    property string vizMode: "off"
    readonly property var vizModes: ["off", "compact", "wide", "full"]
    property int  nightTemp: 6000           // hyprsunset colour temperature, 6000 = off
    readonly property bool nightLight: nightTemp < 6000

    function setOpen(o) {
        if (o) Notifs.setCenter(false)
        open = o
        if (o) nightProbe.running = true
        barSignal.restart()
    }
    function toggle() { setOpen(!open) }

    // ── launching ────────────────────────────────────────────
    // Every GUI program started from Quickshell goes into its own app-*.scope (uwsm app). Spawned directly it
    // would sit in quickshell.service's cgroup, and restarting Quickshell would kill it. Electron apps lose
    // their GPU and network processes that way even though their main process moves to a scope of its own.
    function launch(cmd) { Quickshell.execDetached(["uwsm", "app", "--"].concat(cmd)) }
    // Desktop apps also pass the permissions launch gate, like rofi and the app binds
    function launchApp(cmd) {
        launch(["sh", "-c", 'if command -v perms >/dev/null; then exec perms run "$@"; else exec "$@"; fi', "sh"].concat(cmd))
    }

    // ── media on bar, visualiser ─────────────────────────────
    // waybar reloads its CSS when style.css changes; state.css is @imported from it. It hides the media group
    // when it is off the bar, and the workspaces copy not in use (the left one, beside the weather, in wide mode).
    // Its rules are scoped to window#waybar so they outrank style.css, which imports them first.
    // viz-mode tells ~/.local/bin/viz (custom/viz, custom/viz#wide) which of them runs.
    function setMediaOnBar(on) { mediaOnBar = on; saveBarState() }
    function setVizMode(m) { if (vizModes.includes(m)) { vizMode = m; saveBarState() } }
    function cycleViz() { setVizMode(vizModes[(vizModes.indexOf(vizMode) + 1) % vizModes.length]) }

    function barCss() {
        const hide = sel => "window#waybar " + sel + ", window#waybar " + sel + " * { font-size: 0px; padding: 0; margin: 0; min-width: 0; border: none; background: none; opacity: 0; }"
        const rules = ["/* written by the Quickshell panel: media " + (mediaOnBar ? "shown" : "hidden") + ", visualiser " + vizMode + " */"]
        // full: BarViz draws the glass itself; below the blur rule's ignore_alpha Hyprland leaves the bar unblurred,
        // so the bars stay sharp behind the modules (window#waybar.top outranks style.css's window#waybar)
        if (vizMode === "full") rules.push("window#waybar.top { background: transparent; }")
        if (!mediaOnBar) rules.push(hide("#media"))
        rules.push(hide(vizMode === "wide" ? "#workspaces:not(.left)" : "#workspaces.left"))
        return rules.join("\n") + "\n"
    }
    function saveBarState() {
        stateCss.setText(barCss())
        modeFile.setText(vizMode + "\n")
        Quickshell.execDetached(["touch", Quickshell.env("HOME") + "/.config/waybar/style.css"])
        settings.setText(JSON.stringify({ mediaOnBar: mediaOnBar, vizMode: vizMode }))
    }
    FileView { id: stateCss; path: Quickshell.env("HOME") + "/.config/waybar/state.css"; printErrors: false }
    FileView { id: modeFile; path: Quickshell.env("HOME") + "/.config/waybar/viz-mode"; printErrors: false }
    FileView {
        id: settings; path: Quickshell.statePath("panel.json"); blockLoading: true; printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text())
                if (j.mediaOnBar !== undefined) root.mediaOnBar = j.mediaOnBar
                if (root.vizModes.includes(j.vizMode)) root.vizMode = j.vizMode
                modeFile.setText(root.vizMode + "\n")
            } catch (e) {}
        }
    }

    // ── night light (hyprsunset) ─────────────────────────────
    Process {
        id: nightProbe
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); if (!isNaN(v)) root.nightTemp = v } }
    }
    function setNightLight(on) {
        nightTemp = on ? 4000 : 6000
        Quickshell.execDetached(["hyprctl", "hyprsunset", on ? "temperature" : "identity"].concat(on ? ["4000"] : []))
    }

    // waybar's custom/panel module re-runs `qs ipc call panel status` on RTMIN+10
    Timer { id: barSignal; interval: 50; onTriggered: Quickshell.execDetached(["pkill", "-RTMIN+10", "waybar"]) }
    function status() { return JSON.stringify({ text: "", alt: open ? "open" : "closed", class: open ? "open" : "closed", tooltip: "Widget panel (SUPER+A)" }) }

    IpcHandler {
        target: "panel"
        function toggle(): void { root.toggle() }
        function open(): void   { root.setOpen(true) }
        function close(): void  { root.setOpen(false) }
        function status(): string { return root.status() }
        function mediabar(): void { root.setMediaOnBar(!root.mediaOnBar) }
        function viz(): void { root.cycleViz() }
        function vizmode(mode: string): void { root.setVizMode(mode) }
    }
}
