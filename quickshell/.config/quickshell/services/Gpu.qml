// GPU numbers from the LACT daemon (/run/lactd.sock, wheel group), only while the panel is open.
// Writes go through `lact cli` because it handles LACT's confirm-or-revert step.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string id: ""            // dedicated GPU id, from list_devices
    property string name: ""
    property var stats: null          // device_stats.data
    property bool available: false
    property bool busy: false

    readonly property real   busyPct:  stats ? stats.busy_percent : 0
    readonly property real   tempEdge: stats && stats.temps.edge ? stats.temps.edge.current : 0
    readonly property real   tempJunc: stats && stats.temps.junction ? stats.temps.junction.current : 0
    readonly property real   tempMem:  stats && stats.temps.mem ? stats.temps.mem.current : 0
    readonly property int    clock:    stats ? stats.clockspeed.gpu_clockspeed : 0
    readonly property int    vclock:   stats ? stats.clockspeed.vram_clockspeed : 0
    readonly property real   vramUsed: stats ? stats.vram.used / 1073741824 : 0
    readonly property real   vramTotal:stats ? stats.vram.total / 1073741824 : 0
    readonly property real   power:    stats && stats.power.average !== null ? stats.power.average : 0
    readonly property real   cap:      stats ? stats.power.cap_current : 0
    readonly property real   capMin:   stats ? stats.power.cap_min : 0
    readonly property real   capMax:   stats ? stats.power.cap_max : 0
    readonly property real   capDefault: stats ? stats.power.cap_default : 0
    readonly property int    fanPct:   stats ? Math.round(stats.fan.pwm_current / Math.max(1, stats.fan.pwm_max) * 100) : 0
    readonly property int    fanRpm:   stats && stats.fan.speed_current !== null ? stats.fan.speed_current : 0

    Socket {
        id: sock
        path: "/run/lactd.sock"
        connected: Panel.open
        onConnectedChanged: if (connected) { root.available = true; if (root.id === "") write('{"command":"list_devices"}\n'); else poll.triggered() }
        onError: root.available = false
        parser: SplitParser {
            onRead: line => {
                let r; try { r = JSON.parse(line) } catch (e) { return }
                if (r.status !== "ok") return
                if (Array.isArray(r.data)) {                       // list_devices
                    const d = r.data.find(x => x.device_type === "Dedicated") || r.data[0]
                    if (d) { root.id = d.id; root.name = d.name.replace(/^AMD /, ""); poll.triggered() }
                } else if (r.data && r.data.busy_percent !== undefined) {
                    root.stats = r.data
                }
            }
        }
    }
    Timer {
        id: poll
        interval: 3000; repeat: true
        running: Panel.open && sock.connected && root.id !== ""
        onTriggered: sock.write('{"command":"device_stats","args":{"id":"' + root.id + '"}}\n')
    }

    Process { id: setter; onExited: { root.busy = false; poll.triggered() } }
    function setCap(w) {
        if (busy || id === "") return
        busy = true
        setter.command = ["lact", "cli", "-g", id, "power-limit", "set", String(Math.round(w))]
        setter.running = true
    }
}
