// A strip of live spectrum bars on the Now playing card. `shown` says whether the card is on screen; the strip
// holds services/Viz.qml (and so cava) only while it is.
import QtQuick
import ".."
import "../services"

Item {
    id: root
    property bool shown: false
    readonly property int count: 48
    readonly property var heights: Viz.bins(count)
    onShownChanged: Viz.hold("nowplaying", shown)
    Component.onCompleted: Viz.hold("nowplaying", shown)
    Component.onDestruction: Viz.hold("nowplaying", false)

    Row {
        id: row
        anchors.fill: parent
        readonly property real slot: width / root.count
        Repeater {
            model: root.heights.length
            Item {
                required property int index
                width: row.slot; height: row.height
                Rectangle {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    width: Math.max(1, row.slot * 0.55)
                    height: Math.max(1, row.height * Math.min(1, (root.heights[index] || 0) / Viz.maxLevel))
                    color: Theme.accent
                }
            }
        }
    }
}
