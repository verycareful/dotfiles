// The Music screen: the song visualiser full screen, in the look chosen in Settings (or by the chips and
// Left/Right here), with the album art, title, artist and playback buttons below, and the lyrics beside them in the
// same row, or down the right when clicked (and back when clicked again). A third dashboard view: a click on the Now playing
// card opens it. It holds services/Viz.qml (and so its audio source) only while it is shown.
// Everything inside the margins takes the clicks; a click in the margin, which is the dim, closes the dashboard.
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../viz"
import "../settings"

Item {
    id: music
    property bool active: false
    property bool lyricsSide: false             // true: lyrics down the right; false: along the bottom
    signal lyricsClicked
    readonly property var player: Media.player
    readonly property bool shown: active && player !== null
    onShownChanged: Viz.hold("music", shown)
    Component.onCompleted: Viz.hold("music", shown)
    Component.onDestruction: Viz.hold("music", false)

    readonly property int marginX: 64
    readonly property int marginY: 40
    readonly property int infoHeight: 180       // the art's side
    readonly property int titleWidth: 520       // the title column, while the lyrics share its row
    readonly property int rowSize: 22           // the lyrics in the row
    readonly property int lyricsWidth: 560      // the lyrics down the right
    readonly property int sideSize: 26          // the current line is a quarter larger
    readonly property int buttonsGap: 14
    readonly property int gap: 24
    readonly property var labels: ["Bars", "Waveform", "Radial", "Waterfall"]

    Text {
        anchors.centerIn: parent
        visible: music.player === null
        text: "Nothing playing"
        color: Theme.muted
        font { family: Theme.fontUi; pixelSize: 22; weight: Font.DemiBold }
    }

    MouseArea { anchors.fill: layout; visible: music.player !== null }

    RowLayout {
        id: layout
        visible: music.player !== null
        anchors { fill: parent; leftMargin: music.marginX; rightMargin: music.marginX; topMargin: music.marginY; bottomMargin: music.marginY }
        spacing: music.gap

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: music.gap

            Look {
                Layout.fillWidth: true; Layout.fillHeight: true
                style: Panel.vizStyle
                art: music.player ? music.player.trackArtUrl : ""
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: music.infoHeight
                RowLayout {
                    anchors.fill: parent
                    spacing: music.gap

                    // the radial look carries the art in its centre
                    Rectangle {
                        visible: Panel.vizStyle !== "radial"
                        Layout.preferredWidth: music.infoHeight; Layout.preferredHeight: music.infoHeight
                        color: Theme.surface
                        Image { anchors.fill: parent; source: music.player ? music.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        Glyph { anchors.centerIn: parent; visible: !music.player || music.player.trackArtUrl === ""; text: "\u{F075A}"; color: Theme.muted; size: 48 }
                    }
                    ColumnLayout {
                        id: titleColumn
                        Layout.fillWidth: music.lyricsSide
                        Layout.preferredWidth: music.titleWidth
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6
                        Text { Layout.fillWidth: true; text: music.player ? music.player.trackTitle : ""; color: Theme.text; elide: Text.ElideRight; font { family: Theme.fontDisplay; pixelSize: 44; weight: Font.Bold } }
                        Text {
                            Layout.fillWidth: true
                            text: music.player ? [music.player.trackArtist, music.player.trackAlbum].filter(s => s).join("  ·  ") : ""
                            color: Theme.subtext; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 20; weight: Font.DemiBold }
                        }
                        Transport { Layout.topMargin: music.buttonsGap; player: music.player }
                    }
                    Item { visible: !music.lyricsSide; Layout.fillWidth: true }
                    Choice {
                        Layout.alignment: Qt.AlignBottom
                        options: Panel.vizStyles
                        labels: music.labels
                        value: Panel.vizStyle
                        onPicked: v => Panel.setVizStyle(v)
                    }
                }

                // the lyrics, centred on the screen between the title and the look chips
                Item {
                    visible: !music.lyricsSide
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
                    width: parent.width - 2 * (titleColumn.x + titleColumn.width + music.gap)
                    LyricsView { anchors.fill: parent; size: music.rowSize; align: Text.AlignHCenter }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: music.lyricsClicked() }
                }
            }
        }

        Rectangle { visible: music.lyricsSide; Layout.fillHeight: true; implicitWidth: 1; color: Theme.overlay }

        Item {
            visible: music.lyricsSide
            Layout.preferredWidth: music.lyricsWidth
            Layout.fillHeight: true
            LyricsView { anchors.fill: parent; size: music.sideSize }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: music.lyricsClicked() }
        }
    }
}
