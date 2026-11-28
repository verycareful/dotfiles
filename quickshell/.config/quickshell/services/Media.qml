// The player the dashboard shows: the one playing, else one that has a title, else the first. `playerctld` is a
// proxy for the others and never counts. `player` is null when there is none. While the dashboard is open and the
// player plays, its position is refreshed every tickMs (MPRIS does not announce it): the seek bar and the lyric
// lines change on it.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    readonly property int tickMs: 250
    readonly property var player: {
        const ps = Mpris.players.values.filter(p => p.identity !== "playerctld" && !(p.dbusName || "").includes("playerctld"))
        return ps.find(p => p.isPlaying) || ps.find(p => p.trackTitle !== "") || ps[0] || null
    }
    Timer { interval: Media.tickMs; running: Panel.open && Media.player !== null && Media.player.isPlaying; repeat: true; onTriggered: Media.player.positionChanged() }
}
