// Dashboard state + IPC (the `panel` target: the station's hub, the bar's anchor). `open` is the dashboard's.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    property bool settingsOpen: false      // the settings window, which shows the same widgets
    readonly property bool watched: open || settingsOpen   // the services poll while either is showing
    property bool releaseKeyboard: false   // true while a polkit dialog is up, so it gets the keys
    property bool mediaOnBar: true          // "Media on bar" toggle → waybar state.css
    property int  nightTemp: 6000           // hyprsunset colour temperature, 6000 = off
    readonly property bool nightLight: nightTemp < 6000

    function setOpen(o) {
        if (o) { Notifs.clearPopups(); dashboardParked = false }      // the dashboard lists every notification
        open = o
        if (o) nightProbe.running = true
        barSignal.restart()
    }
    function toggle() { setOpen(!open) }

    // ── windows opened from the dashboard ────────────────────
    // The Themes, DNS, Permissions and Tray windows are ordinary windows, which sit under every layer, and Settings
    // is a Top layer under the dashboard's Overlay: none can show over it. Opened while the dashboard shows, each
    // parks it; closing the window brings the dashboard back on the view it was on (the dashboard persists
    // `dashboardParked` across a shell reload, which a theme switch causes).
    property bool dashboardParked: false
    property bool resuming: false              // the dashboard is coming back: it keeps its view
    function parkDashboard() {
        if (!open) return
        setOpen(false)
        dashboardParked = true
    }
    function resumeDashboard() {
        if (!dashboardParked || settingsOpen) return     // Settings resumes it when it closes
        resuming = true
        setOpen(true)                          // clears dashboardParked
        resuming = false
    }

    // ── launching ────────────────────────────────────────────
    // Every GUI program started from Quickshell goes into its own app-*.scope (uwsm app). Spawned directly it
    // would sit in quickshell.service's cgroup, and restarting Quickshell would kill it. Electron apps lose
    // their GPU and network processes that way even though their main process moves to a scope of its own.
    function launch(cmd) { Quickshell.execDetached(["uwsm", "app", "--"].concat(cmd)) }
    // Desktop apps also pass the permissions launch gate, like rofi and the app binds
    function launchApp(cmd) {
        launch(["sh", "-c", 'if command -v perms >/dev/null; then exec perms run "$@"; else exec "$@"; fi', "sh"].concat(cmd))
    }

    // ── media on bar ─────────────────────────────────────────
    // waybar reloads its CSS when style.css changes; state.css is @imported from it. It hides the media group
    // when it is off the bar. Its rules are scoped to window#waybar so they outrank style.css, which imports
    // them first.
    function setMediaOnBar(on) { mediaOnBar = on; saveBarState() }

    function barCss() {
        const hide = sel => "window#waybar " + sel + ", window#waybar " + sel + " * { font-size: 0px; padding: 0; margin: 0; min-width: 0; border: none; background: none; opacity: 0; }"
        const rules = ["/* written by the Quickshell panel: media " + (mediaOnBar ? "shown" : "hidden") + " */"]
        if (!mediaOnBar) rules.push(hide("#media"))
        return rules.join("\n") + "\n"
    }
    function saveBarState() {
        stateCss.setText(barCss())
        Quickshell.execDetached(["touch", Quickshell.env("HOME") + "/.config/waybar/style.css"])
        saveSettings()
    }

    // ── song visualiser look ─────────────────────────────────
    // The look on the Music screen and the Now playing strip; picked there or in Settings, kept in panel.json.
    readonly property var vizStyles: ["bars", "waveform", "radial", "waterfall"]
    property string vizStyle: "bars"
    function setVizStyle(style) {
        if (!vizStyles.includes(style) || style === vizStyle) return
        vizStyle = style
        saveSettings()
    }
    function cycleViz(step) {
        const n = vizStyles.length
        setVizStyle(vizStyles[(vizStyles.indexOf(vizStyle) + step + n) % n])
    }

    // How the spectrum is laid out: mono runs from the lowest frequency on the left to the highest on the right;
    // stereo mirrors it about the middle (services/Viz.qml picks the cava config).
    readonly property var vizLayouts: ["mono", "stereo"]
    property string vizLayout: "mono"
    function setVizLayout(layout) {
        if (!vizLayouts.includes(layout) || layout === vizLayout) return
        vizLayout = layout
        saveSettings()
    }

    function saveSettings() { settings.setText(JSON.stringify({ mediaOnBar: mediaOnBar, vizStyle: vizStyle, vizLayout: vizLayout })) }
    FileView { id: stateCss; path: Quickshell.env("HOME") + "/.config/waybar/state.css"; blockLoading: true; printErrors: false }
    FileView {
        id: settings; path: Quickshell.statePath("panel.json"); blockLoading: true; printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text())
                if (j.mediaOnBar !== undefined) root.mediaOnBar = j.mediaOnBar
                if (root.vizStyles.includes(j.vizStyle)) root.vizStyle = j.vizStyle
                if (root.vizLayouts.includes(j.vizLayout)) root.vizLayout = j.vizLayout
            } catch (e) {}
            // a state.css written by an older shell (it could hide the centre workspaces) is replaced; one that
            // already matches is left alone, so a reload does not make Waybar re-read its CSS
            if (stateCss.text() !== root.barCss()) root.saveBarState()
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

    // ── windows opened from Settings ─────────────────────────
    // openWindow(name) shows the themes, dns or perms window. Opened while Settings shows, it closes Settings
    // first and that window's close brings Settings back on the same page (the window calls backToSettings).
    // runPicker(cmd, page) does the same for a rofi picker: Settings comes back on `page` when it exits.
    signal windowRequested(string name, bool fromSettings)
    signal settingsClose()
    signal settingsReturn()
    function openWindow(name) {
        const back = settingsOpen
        if (back) settingsClose()
        windowRequested(name, back)
    }
    function backToSettings() { settingsReturn() }
    function runPicker(cmd, page) {
        if (!settingsOpen) { launch(cmd); return }
        settingsClose()
        launch(["sh", "-c", '"$@"; exec qs ipc call settings open "$0"', page].concat(cmd))
    }

    // waybar's custom/panel module re-runs `qs ipc call panel status` on RTMIN+10
    Timer { id: barSignal; interval: 50; onTriggered: Quickshell.execDetached(["pkill", "-RTMIN+10", "waybar"]) }
    function status() { return JSON.stringify({ text: "", alt: open ? "open" : "closed", class: open ? "open" : "closed", tooltip: "Dashboard" }) }

    IpcHandler {
        target: "panel"
        function toggle(): void { root.toggle() }
        function open(): void   { root.setOpen(true) }
        function close(): void  { root.setOpen(false) }
        function status(): string { return root.status() }
        function mediabar(): void { root.setMediaOnBar(!root.mediaOnBar) }
        function viz(style: string): void { root.setVizStyle(style) }
        function vizlayout(layout: string): void { root.setVizLayout(layout) }
    }
}
