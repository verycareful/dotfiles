// Song visualiser source: runs while a view holds it and a player is playing. The waveform look reads `wave` from
// the viz-wave relay; every other look reads `levels` from cava, so exactly one of the two runs. A view calls
// hold(who, true) while it shows the visualiser and hold(who, false) when it stops (and on destruction); with no
// holder, or nothing playing, neither runs. A short grace keeps the source alive across a hand-over between two
// views. cava's settings are in viz/cava.conf (mono) and viz/cava-stereo.conf, chosen by Panel.vizLayout.
pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property int bars: 160         // cava.conf bars
    readonly property int maxLevel: 1000    // cava.conf ascii_max_range, and the relay's peak
    readonly property int stopGraceMs: 400  // one view hands over to another within this
    readonly property string style: Panel.vizStyle
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying && !(p.dbusName || "").includes("playerctld"))
    property var holders: ({})
    readonly property bool wanted: Object.keys(holders).length > 0
    readonly property bool active: (wanted || grace.running) && playing
    property var levels: []                 // `bars` numbers in 0..maxLevel; empty while cava is not running
    property var wave: []                   // up to 256 numbers in -maxLevel..maxLevel; empty while the relay is not running
    onWantedChanged: if (!wanted) grace.restart()
    Timer { id: grace; interval: root.stopGraceMs }

    function hold(who: string, on: bool): void {
        const next = Object.assign({}, holders)
        if (on) next[who] = true
        else delete next[who]
        holders = next
    }

    // mono runs from the lowest frequency (first bar) to the highest (last); stereo mirrors it about the middle, the
    // lowest frequencies in the centre (the `channels` line of the cava config Panel.vizLayout picks)
    readonly property bool mirrored: Panel.vizLayout === "stereo"

    // 0..1: the level of the four lowest-frequency bars
    function bass(): real {
        const n = levels.length
        if (n < 4) return 0
        const from = mirrored ? (n >> 1) - 2 : 0
        return (levels[from] + levels[from + 1] + levels[from + 2] + levels[from + 3]) / 4 / maxLevel
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

    // one cava per layout: while one is wanted the model holds the layout's name, so a change of layout replaces the
    // process, and no longer wanting it removes it
    readonly property bool cavaWanted: active && style !== "waveform"
    onCavaWantedChanged: if (!cavaWanted) levels = []
    Instantiator {
        model: root.cavaWanted ? [Panel.vizLayout] : []
        delegate: Process {
            required property string modelData
            running: true
            command: ["cava", "-p", Quickshell.shellPath(modelData === "stereo" ? "viz/cava-stereo.conf" : "viz/cava.conf")]
            stdout: SplitParser { onRead: line => root.levels = line.split(";").filter(s => s !== "").map(Number) }
        }
    }
    Process {
        running: root.active && root.style === "waveform"
        command: ["viz-wave"]
        stdout: SplitParser { onRead: line => root.wave = line.split(";").map(Number) }
        onRunningChanged: if (!running) root.wave = []
    }
}
