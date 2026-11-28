// The signal as one line across the width, redrawn on every frame the relay sends. No smoothing: it moves exactly
// when the sound does. A faint line marks zero.
import QtQuick
import QtQuick.Shapes
import ".."
import "../services"

Item {
    id: root
    property bool compact: false
    readonly property real fill: 0.7            // of the half height at full scale
    readonly property var points: {
        const w = Viz.wave
        const n = w.length
        if (n < 2) return []
        const half = height / 2
        const out = []
        for (let i = 0; i < n; i++) out.push(Qt.point(i / (n - 1) * width, half - w[i] / Viz.maxLevel * half * fill))
        return out
    }

    Rectangle { width: parent.width; height: 1.5; y: parent.height / 2 - height / 2; color: Theme.accent; opacity: 0.25 }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: root.compact ? 2 : 3
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.points }
        }
    }
}
