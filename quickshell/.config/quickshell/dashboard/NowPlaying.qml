// Now playing: album art | title, artist, album, seek, controls, volume | lyrics. Any MPRIS player; hidden when
// there is none (`player` is null). Lyrics come from ~/.local/bin/lyrics (LRCLIB, cached), looked up while the
// dashboard is open; synced lyrics scroll with the song and light the current line.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."
import "../services"
import "../panel"

Widgets.Tile {
    id: card
    readonly property int pad: 16
    readonly property int infoWidth: 440
    readonly property int tickMs: 250             // position refresh while playing: lyric lines change on it
    readonly property int lookupDelayMs: 400      // players publish title, artist and length one by one

    readonly property var player: {
        const ps = Mpris.players.values.filter(p => p.identity !== "playerctld" && !(p.dbusName || "").includes("playerctld"))
        return ps.find(p => p.isPlaying) || ps.find(p => p.trackTitle !== "") || ps[0] || null
    }
    Timer { interval: card.tickMs; running: card.visible && Panel.open && card.player && card.player.isPlaying; repeat: true; onTriggered: card.player.positionChanged() }
    MouseArea { anchors.fill: parent; z: -1 }     // clicks on the card never reach the closer underneath
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    // ── lyrics ───────────────────────────────────────────────
    readonly property string trackKey: player ? [player.trackTitle, player.trackArtist, player.trackAlbum].join("\n") : ""
    property string lyricsKey: ""                 // the track `lyrics` holds
    property var lyrics: ({ synced: [], plain: [], instrumental: false, found: false })
    property bool looking: false
    readonly property bool synced: lyrics.synced.length > 0
    readonly property int line: {                 // the synced line being sung (-1 before the first)
        if (!synced || !player) return -1
        const t = player.position, l = lyrics.synced
        let lo = 0, hi = l.length - 1, at = -1
        while (lo <= hi) { const mid = (lo + hi) >> 1; if (l[mid][0] <= t) { at = mid; lo = mid + 1 } else hi = mid - 1 }
        return at
    }
    onTrackKeyChanged: lookupTimer.restart()
    Connections { target: Panel; function onOpenChanged() { if (Panel.open) lookupTimer.restart() } }
    Timer {
        id: lookupTimer
        interval: card.lookupDelayMs
        onTriggered: {
            if (!Panel.open || !card.player || card.player.trackTitle === "" || card.trackKey === card.lyricsKey) return
            card.lyricsKey = card.trackKey
            card.lyrics = { synced: [], plain: [], instrumental: false, found: false }
            card.looking = true
            lookup.command = ["lyrics", card.player.trackTitle, card.player.trackArtist, card.player.trackAlbum,
                              String(card.player.lengthSupported ? Math.round(card.player.length) : 0)]
            lookup.running = true
        }
    }
    Process {
        id: lookup
        property string forKey: ""
        onStarted: forKey = card.lyricsKey
        stdout: StdioCollector {
            onStreamFinished: {
                if (lookup.forKey !== card.lyricsKey) return        // the song changed meanwhile
                try { card.lyrics = JSON.parse(text) } catch (e) {}
                card.looking = false
            }
        }
        onExited: code => { if (code !== 0) card.looking = false }
    }

    RowLayout {
        anchors { fill: parent; margins: card.pad }
        spacing: 20

        // art
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            color: Theme.surface
            Image { anchors.fill: parent; source: card.player ? card.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Glyph { anchors.centerIn: parent; visible: !card.player || card.player.trackArtUrl === ""; text: "\u{F075A}"; color: Theme.muted; size: 48 }
        }

        // info + controls
        ColumnLayout {
            Layout.preferredWidth: card.infoWidth
            Layout.fillWidth: false                   // its seek bar fills width; the lyrics take the rest
            Layout.fillHeight: true
            spacing: 6
            Widgets.Heading { text: "NOW PLAYING" }
            Text { Layout.fillWidth: true; text: card.player ? card.player.trackTitle : ""; color: Theme.text; elide: Text.ElideRight; font { family: Theme.fontDisplay; pixelSize: 26; weight: Font.Bold } }
            Text { Layout.fillWidth: true; text: card.player ? card.player.trackArtist : ""; color: Theme.subtext; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 16; weight: Font.DemiBold } }
            Text {
                Layout.fillWidth: true
                text: card.player ? [card.player.trackAlbum, card.player.identity].filter(s => s).join("  ·  ") : ""
                color: Theme.muted; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 13; weight: Font.DemiBold }
            }
            Item { Layout.fillHeight: true }
            RowLayout {                                   // seek
                Layout.fillWidth: true
                spacing: 10
                Text { text: card.player ? card.fmt(card.player.position) : ""; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
                Item {
                    id: seek
                    Layout.fillWidth: true; implicitHeight: 16
                    readonly property real frac: card.player && card.player.length > 0 ? card.player.position / card.player.length : 0
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: Theme.overlay }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: seek.frac * parent.width; height: 4; color: Theme.accent }
                    MouseArea { anchors.fill: parent; enabled: card.player && card.player.canSeek; onClicked: mouse => card.player.position = mouse.x / width * card.player.length }
                }
                Text { text: card.player && card.player.lengthSupported ? card.fmt(card.player.length) : ""; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
            }
            RowLayout {                                   // controls + volume
                Layout.fillWidth: true
                spacing: 6
                MBtn { glyph: "\u{F04AE}"; enabled: card.player && card.player.canGoPrevious; onClicked: card.player.previous() }
                MBtn { glyph: card.player && card.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"; big: true; onClicked: card.player.togglePlaying() }
                MBtn { glyph: "\u{F04AD}"; enabled: card.player && card.player.canGoNext; onClicked: card.player.next() }
                Item { Layout.fillWidth: true }
                Glyph { visible: card.player && card.player.volumeSupported; text: "\u{F057E}"; color: Theme.muted; size: 16 }
                Item {
                    visible: card.player && card.player.volumeSupported
                    implicitWidth: 120; implicitHeight: 16
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: Theme.overlay }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: (card.player ? card.player.volume : 0) * parent.width; height: 4; color: Theme.primaryBright }
                    MouseArea { anchors.fill: parent; onClicked: mouse => card.player.volume = Math.max(0, Math.min(1, mouse.x / width)); onPositionChanged: mouse => { if (pressed) card.player.volume = Math.max(0, Math.min(1, mouse.x / width)) } }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.overlay }

        // lyrics
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: lines
                anchors.fill: parent
                visible: card.synced || card.lyrics.plain.length > 0
                model: card.synced ? card.lyrics.synced : card.lyrics.plain
                spacing: 8
                interactive: !card.synced && contentHeight > height     // plain lyrics scroll by hand
                currentIndex: card.synced ? Math.max(0, card.line) : -1
                highlightRangeMode: card.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                preferredHighlightBegin: height / 2 - 20
                preferredHighlightEnd: height / 2 + 20
                highlightMoveDuration: 300
                delegate: Text {
                    required property var modelData
                    required property int index
                    readonly property bool now: card.synced && index === card.line
                    width: ListView.view.width
                    wrapMode: Text.WordWrap
                    text: (card.synced ? modelData[1] : modelData) || "♪"
                    color: now ? Theme.text : (card.synced && index < card.line ? Theme.muted : Theme.subtext)
                    font { family: Theme.fontUi; pixelSize: now ? 20 : 16; weight: Font.DemiBold }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !lines.visible
                text: card.looking ? "Looking up lyrics…" : (card.lyrics.instrumental ? "Instrumental" : (card.lyrics.error ? "Lyrics unavailable (offline?)" : "No lyrics found"))
                color: Theme.muted
                font { family: Theme.fontUi; pixelSize: 14; weight: Font.DemiBold }
            }
        }
    }

    component MBtn: Rectangle {
        property string glyph
        property bool big: false
        signal clicked
        implicitWidth: big ? 48 : 38; implicitHeight: big ? 48 : 38
        color: mm.containsMouse && enabled ? Theme.fillHover : "transparent"
        border.width: big ? 1 : 0; border.color: Theme.overlay
        Glyph { anchors.centerIn: parent; text: parent.glyph; color: parent.enabled ? (mm.containsMouse ? Theme.accent : Theme.text) : Theme.muted; size: parent.big ? 26 : 20 }
        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.enabled) parent.clicked() }
    }
}
