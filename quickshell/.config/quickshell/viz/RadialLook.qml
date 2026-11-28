// Spectrum bars on a ring around the album art; the art swells on the bass. With no art the disc shows a note
// glyph, so the ring is never empty at the centre.
import QtQuick
import QtQuick.Effects
import ".."
import "../services"

Item {
    id: root
    property bool compact: false                // unused: the ring is always drawn at the size it is given
    property url art
    readonly property int count: 72
    readonly property real size: Math.min(width, height)
    readonly property real inner: size * 0.2    // ring radius
    readonly property real longest: size * 0.22
    readonly property real barWidth: Math.max(2, size * 0.011)
    readonly property real swellRest: 0.82      // disc radius as a share of the ring, at rest and on a full bass
    readonly property real swellBass: 0.08
    // the ring is symmetric left to right, the lowest frequencies at the top: one spectrum is drawn down the right
    // side and mirrored up the left (a mirrored spectrum already is symmetric)
    readonly property var heights: {
        if (Viz.mirrored) return Viz.bins(count)
        const half = Viz.bins(count / 2)
        return half.concat(half.slice().reverse())
    }
    readonly property real bass: Viz.bass()

    Repeater {
        model: root.heights.length
        Item {
            required property int index
            x: root.width / 2; y: root.height / 2
            rotation: index / root.count * 360
            Rectangle {
                x: -width / 2
                y: -(root.inner + height)
                width: root.barWidth; radius: width / 2
                height: Math.max(root.barWidth, root.longest * Math.min(1, (root.heights[index] || 0) / Viz.maxLevel))
                color: Theme.accent
            }
        }
    }

    Item {
        id: disc
        anchors.centerIn: parent
        width: root.inner * 2; height: width
        scale: root.swellRest + root.swellBass * root.bass
        Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.surface }
        Image { id: img; anchors.fill: parent; source: root.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
        Rectangle { id: mask; anchors.fill: parent; radius: width / 2; layer.enabled: true; visible: false }
        MultiEffect { anchors.fill: parent; source: img; maskEnabled: true; maskSource: mask; visible: root.art != "" }
        Glyph { anchors.centerIn: parent; visible: root.art == ""; text: "\u{F075A}"; color: Theme.muted; size: root.inner * 0.6 }
    }
}
