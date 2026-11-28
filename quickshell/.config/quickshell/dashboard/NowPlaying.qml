// Now playing: album art | title, artist, album, seek, controls, volume | lyrics. Any MPRIS player; hidden when
// there is none (`player` is null). A click on the card opens the Music screen.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../panel"

Widgets.Tile {
    id: card
    readonly property int pad: 16
    readonly property int infoWidth: 440

    readonly property var player: Media.player
    property bool active: true                    // false while another dashboard view is shown
    signal openMusic
    MouseArea { anchors.fill: parent; z: -1; onClicked: card.openMusic() }   // a click on the card opens the Music screen, and never reaches the closer underneath
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

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
            VizStrip {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                shown: card.visible && Panel.open && card.active && card.player !== null
            }
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
                Transport { player: card.player }
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
        LyricsView { Layout.fillWidth: true; Layout.fillHeight: true }
    }
}
