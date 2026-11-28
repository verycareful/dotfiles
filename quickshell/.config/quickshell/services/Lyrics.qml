// Lyrics for the track Media.player is on, from ~/.local/bin/lyrics (LRCLIB, cached), looked up while the dashboard
// is open. `data` holds { synced: [[seconds, line], ...], plain: [line, ...], instrumental, found } (and `error` when
// LRCLIB could not be reached); `line` is the synced line being sung.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property int lookupDelayMs: 400      // players publish title, artist and length one by one
    readonly property var player: Media.player

    readonly property string trackKey: player ? [player.trackTitle, player.trackArtist, player.trackAlbum].join("\n") : ""
    property string lyricsKey: ""                 // the track `data` holds
    property var data: ({ synced: [], plain: [], instrumental: false, found: false })
    property bool looking: false
    readonly property bool synced: data.synced.length > 0
    readonly property int line: {                 // the synced line being sung (-1 before the first)
        if (!synced || !player) return -1
        const t = player.position, l = data.synced
        let lo = 0, hi = l.length - 1, at = -1
        while (lo <= hi) { const mid = (lo + hi) >> 1; if (l[mid][0] <= t) { at = mid; lo = mid + 1 } else hi = mid - 1 }
        return at
    }
    onTrackKeyChanged: lookupTimer.restart()
    Connections { target: Panel; function onOpenChanged() { if (Panel.open) lookupTimer.restart() } }
    Timer {
        id: lookupTimer
        interval: root.lookupDelayMs
        onTriggered: {
            if (!Panel.open || !root.player || root.player.trackTitle === "" || root.trackKey === root.lyricsKey) return
            root.lyricsKey = root.trackKey
            root.data = { synced: [], plain: [], instrumental: false, found: false }
            root.looking = true
            lookup.command = ["lyrics", root.player.trackTitle, root.player.trackArtist, root.player.trackAlbum,
                              String(root.player.lengthSupported ? Math.round(root.player.length) : 0)]
            lookup.running = true
        }
    }
    Process {
        id: lookup
        property string forKey: ""
        onStarted: forKey = root.lyricsKey
        stdout: StdioCollector {
            onStreamFinished: {
                if (lookup.forKey !== root.lyricsKey) return        // the song changed meanwhile
                try { root.data = JSON.parse(text) } catch (e) {}
                root.looking = false
            }
        }
        onExited: code => { if (code !== 0) root.looking = false }
    }
}
