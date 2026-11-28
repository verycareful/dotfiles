// Spectrum bars mirrored about the middle line. cava does the smoothing: the bars rise at once and fall quickly.
import QtQuick
import ".."
import "../services"

Item {
    id: root
    property bool compact: false
    readonly property int count: compact ? 48 : 96
    readonly property var heights: Viz.bins(count)
    readonly property real slot: width / count

    Repeater {
        model: root.heights.length
        Rectangle {
            required property int index
            x: index * root.slot + root.slot * 0.2
            width: root.slot * 0.6
            height: Math.max(2, root.height * Math.min(1, (root.heights[index] || 0) / Viz.maxLevel))
            y: (root.height - height) / 2
            color: Theme.accent
        }
    }
}
