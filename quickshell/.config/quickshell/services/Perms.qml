// Permissions state for perms/PermsWindow.qml: `perms status` every 3 s while the window is open,
// and the rule changes (`perms set` / `perms switch`, which regenerate and reload the rules).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var status: ({})
    property bool windowOpen: false
    property string busy: ""            // "perm:app" or "perm:*" while a change is being applied
    property string error: ""
    signal openWindow()

    readonly property var rules: status.rules || ({})
    readonly property var live: status.live || ({ mic: {}, screen: {}, camera: {} })
    readonly property var seen: status.seen || ({})
    readonly property var system: status.system || []

    function refresh() { if (!statusProc.running) statusProc.running = true }

    // Allow is the default, so it is stored as no rule at all
    function setApp(perm, app, mode) { change(perm + ":" + app, ["perms", "set", perm, app, mode === "allow" ? "clear" : mode]) }
    function setSwitch(perm, on)     { change(perm + ":*", ["perms", "switch", perm, on ? "on" : "off"]) }
    function change(what, cmd) {
        if (busy !== "") return
        busy = what; error = ""
        act.command = cmd
        act.running = true
    }

    function mode(perm, app) {
        const r = rules[perm]
        if (!r || system.indexOf(app) >= 0) return "allow"
        if (!r.on) return "block"
        return (r.apps || {})[app] || "allow"
    }
    function name(app) {
        if ((status.names || {})[app]) return status.names[app]
        for (const k of ["mic", "screen", "camera"]) if (seen[k] && seen[k][app] && seen[k][app].name) return seen[k][app].name
        return app
    }
    // "now", "5 min ago", "2 h ago", "3 days ago"
    function ago(t) {
        if (!t) return ""
        const s = Math.max(0, Date.now() / 1000 - t)
        if (s < 90) return "just now"
        if (s < 3600) return Math.round(s / 60) + " min ago"
        if (s < 86400) return Math.round(s / 3600) + " h ago"
        const d = Math.round(s / 86400)
        return d + (d === 1 ? " day ago" : " days ago")
    }

    Process {
        id: statusProc
        command: ["perms", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.status = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: act
        stderr: StdioCollector { id: actErr }
        onExited: (code) => {
            root.error = code === 0 ? "" : (actErr.text.trim().split("\n").pop() || "Failed")
            root.busy = ""
            root.refresh()
        }
    }
    Timer { interval: 3000; repeat: true; running: root.windowOpen; triggeredOnStart: true; onTriggered: root.refresh() }
}
