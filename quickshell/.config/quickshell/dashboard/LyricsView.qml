// The lyrics of the track playing (services/Lyrics.qml): synced lines scroll with the song and the current one is
// lit; plain lyrics scroll by hand; otherwise a short message. `size` is the text size, the current line is a
// quarter larger; `align` is the text's horizontal alignment.
import QtQuick
import ".."
import "../services"

Item {
    id: root
    property int size: 16
    property int align: Text.AlignLeft
    clip: true

    ListView {
        id: lines
        anchors.fill: parent
        visible: Lyrics.synced || Lyrics.data.plain.length > 0
        model: Lyrics.synced ? Lyrics.data.synced : Lyrics.data.plain
        spacing: root.size / 2
        interactive: !Lyrics.synced && contentHeight > height     // plain lyrics scroll by hand
        currentIndex: Lyrics.synced ? Math.max(0, Lyrics.line) : -1
        highlightRangeMode: Lyrics.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - root.size * 1.25
        preferredHighlightEnd: height / 2 + root.size * 1.25
        highlightMoveDuration: 300
        delegate: Text {
            required property var modelData
            required property int index
            readonly property bool now: Lyrics.synced && index === Lyrics.line
            width: ListView.view.width
            wrapMode: Text.WordWrap
            horizontalAlignment: root.align
            text: (Lyrics.synced ? modelData[1] : modelData) || "♪"
            color: now ? Theme.text : (Lyrics.synced && index < Lyrics.line ? Theme.muted : Theme.subtext)
            font { family: Theme.fontUi; pixelSize: now ? root.size * 1.25 : root.size; weight: Font.DemiBold }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: !lines.visible
        text: Lyrics.looking ? "Looking up lyrics…" : (Lyrics.data.instrumental ? "Instrumental" : (Lyrics.data.error ? "Lyrics unavailable (offline?)" : "No lyrics found"))
        color: Theme.muted
        font { family: Theme.fontUi; pixelSize: root.size * 0.875; weight: Font.DemiBold }
    }
}
