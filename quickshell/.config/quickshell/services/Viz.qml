// Song visualiser source: runs cava while a view holds it and a player is playing, and publishes cava's frames as
// `levels`. A view calls hold(who, true) while it shows the visualiser and hold(who, false) when it stops (and on
// destruction); with no holder, or nothing playing, cava is not running. cava's settings are in viz/cava.conf.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property int bars: 160         // cava.conf bars
    readonly property int maxLevel: 1000    // cava.conf ascii_max_range
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying && !(p.dbusName || "").includes("playerctld"))
    property var holders: ({})
    readonly property bool wanted: Object.keys(holders).length > 0
    readonly property bool active: wanted && playing
    property var levels: []                 // `bars` numbers in 0..maxLevel; empty while cava is not running

    function hold(who: string, on: bool): void {
        const next = Object.assign({}, holders)
        if (on) next[who] = true
        else delete next[who]
        holders = next
    }

    // `levels` grouped into n bars, each the highest of its group
    function bins(n: int): var {
        const src = levels
        const out = []
        if (src.length === 0) return out
        for (let i = 0; i < n; i++) {
            const from = Math.floor(i * src.length / n)
            const to = Math.max(from + 1, Math.floor((i + 1) * src.length / n))
            let top = 0
            for (let j = from; j < to; j++) top = Math.max(top, src[j])
            out.push(top)
        }
        return out
    }

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellPath("viz/cava.conf")]
        stdout: SplitParser { onRead: line => root.levels = line.split(";").filter(s => s !== "").map(Number) }
        onRunningChanged: if (!running) root.levels = []
    }
}
