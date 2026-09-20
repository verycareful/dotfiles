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
    property int  nightTemp: 6000           // hyprsunset colour temperature, 6000 = off
    readonly property bool nightLight: nightTemp < 6000

    function setOpen(o) {
        if (o) Notifs.setCenter(false)
        open = o
        if (o) nightProbe.running = true
        barSignal.restart()
    }
    function toggle() { setOpen(!open) }

    // ── media on bar ─────────────────────────────────────────
    // waybar reloads its CSS when style.css changes; state.css is @imported from it.
    function setMediaOnBar(on) {
        mediaOnBar = on
        stateCss.setText(on ? "/* media group shown (Quickshell panel) */\n"
                            : "/* media group hidden (Quickshell panel) */\n#media, #media * { font-size: 0px; padding: 0; margin: 0; min-width: 0; border: none; }\n")
        Quickshell.execDetached(["touch", Quickshell.env("HOME") + "/.config/waybar/style.css"])
        settings.setText(JSON.stringify({ mediaOnBar: on }))
    }
    FileView { id: stateCss; path: Quickshell.env("HOME") + "/.config/waybar/state.css"; printErrors: false }
    FileView {
        id: settings; path: Quickshell.statePath("panel.json"); blockLoading: true; printErrors: false
        onLoaded: { try { const j = JSON.parse(text()); if (j.mediaOnBar !== undefined) root.mediaOnBar = j.mediaOnBar } catch (e) {} }
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
    function status() { return JSON.stringify({ text: "", alt: open ? "open" : "closed", class: open ? "open" : "closed", tooltip: "panel (SUPER+A)" }) }

    IpcHandler {
        target: "panel"
        function toggle(): void { root.toggle() }
        function open(): void   { root.setOpen(true) }
        function close(): void  { root.setOpen(false) }
        function status(): string { return root.status() }
        function mediabar(): void { root.setMediaOnBar(!root.mediaOnBar) }
    }
}
