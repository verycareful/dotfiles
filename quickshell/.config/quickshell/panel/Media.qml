// MPRIS media: art · title/artist · prev/play/next · seek · volume. Hidden when nothing is playing.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import ".."
import "../services"

Widgets.Tile {
    id: tile
    visible: player !== null
    implicitHeight: visible ? 96 : 0

    readonly property var player: {
        const ps = Mpris.players.values.filter(p => p.identity !== "playerctld" && !(p.dbusName || "").includes("playerctld"))
        return ps.find(p => p.isPlaying) || ps.find(p => p.trackTitle !== "") || ps[0] || null
    }
    Timer { interval: 1000; running: tile.visible && Panel.open && tile.player && tile.player.isPlaying; repeat: true; onTriggered: tile.player.positionChanged() }
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    RowLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 12
        Rectangle {
            implicitWidth: 76; implicitHeight: 76
            color: Theme.surface
            Image { anchors.fill: parent; source: tile.player ? tile.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Text { anchors.centerIn: parent; visible: !tile.player || tile.player.trackArtUrl === ""; text: "\u{F075A}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 28 } }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { Layout.fillWidth: true; text: tile.player ? tile.player.trackTitle : ""; color: Theme.text; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 13; weight: Font.Bold } }
            Text { Layout.fillWidth: true; text: tile.player ? (tile.player.trackArtist + (tile.player.identity ? "  ·  " + tile.player.identity : "")) : ""; color: Theme.subtext; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 11 } }
            RowLayout {                                   // seek
                Layout.fillWidth: true
                spacing: 8
                Text { text: tile.player ? tile.fmt(tile.player.position) : ""; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
                Item {
                    id: seek
                    Layout.fillWidth: true; implicitHeight: 12
                    readonly property real frac: tile.player && tile.player.length > 0 ? tile.player.position / tile.player.length : 0
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; color: Theme.overlay }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: seek.frac * parent.width; height: 3; color: Theme.accent }
                    MouseArea { anchors.fill: parent; enabled: tile.player && tile.player.canSeek; onClicked: mouse => tile.player.position = mouse.x / width * tile.player.length }
                }
                Text { text: tile.player && tile.player.lengthSupported ? tile.fmt(tile.player.length) : ""; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
            }
            RowLayout {                                   // controls + volume
                Layout.fillWidth: true
                spacing: 2
                MBtn { glyph: "\u{F04AE}"; enabled: tile.player && tile.player.canGoPrevious; onClicked: tile.player.previous() }
                MBtn { glyph: tile.player && tile.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"; onClicked: tile.player.togglePlaying() }
                MBtn { glyph: "\u{F04AD}"; enabled: tile.player && tile.player.canGoNext; onClicked: tile.player.next() }
                Item { Layout.fillWidth: true }
                Text { visible: tile.player && tile.player.volumeSupported; text: "\u{F057E}"; color: Theme.muted; font { family: Theme.fontIcon; pixelSize: 13 } }
                Item {
                    visible: tile.player && tile.player.volumeSupported
                    implicitWidth: 90; implicitHeight: 12
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; color: Theme.overlay }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: (tile.player ? tile.player.volume : 0) * parent.width; height: 3; color: Theme.primaryBright }
                    MouseArea { anchors.fill: parent; onClicked: mouse => tile.player.volume = Math.max(0, Math.min(1, mouse.x / width)); onPositionChanged: mouse => { if (pressed) tile.player.volume = Math.max(0, Math.min(1, mouse.x / width)) } }
                }
            }
        }
    }
    component MBtn: Rectangle {
        property string glyph
        signal clicked
        implicitWidth: 28; implicitHeight: 24
        color: mm.containsMouse && enabled ? Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9) : "transparent"
        Text { anchors.centerIn: parent; text: parent.glyph; color: parent.enabled ? (mm.containsMouse ? Theme.accent : Theme.text) : Theme.muted; font { family: Theme.fontIcon; pixelSize: 16 } }
        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.enabled) parent.clicked() }
    }
}
