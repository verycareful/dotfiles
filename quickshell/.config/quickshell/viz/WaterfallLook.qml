// A scrolling picture of the last few seconds of spectrum: the newest row at the top, each cell brighter where
// the band is louder. A row is kept for every second frame cava sends. The canvas keeps its pixels, so each new
// row is one row of cells drawn after the picture is moved down by a row.
import QtQuick
import ".."
import "../services"

Item {
    id: root
    property bool compact: false
    readonly property int rows: 150             // 5 s at 30 rows a second
    readonly property int cols: compact ? 24 : 64
    readonly property real peakAlpha: 0.95
    property var newest: []
    property int frame: 0

    Connections {
        target: Viz
        function onLevelsChanged() {
            if (Viz.levels.length === 0 || ++root.frame % 2 !== 0) return
            root.newest = Viz.bins(root.cols)
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        onPaint: {
            const ctx = getContext("2d")
            const rowH = Math.max(1, Math.round(height / root.rows)), cellW = width / root.cols, c = Theme.accent
            ctx.globalCompositeOperation = "copy"      // the moved picture replaces the old one
            ctx.drawImage(canvas, 0, rowH)
            ctx.globalCompositeOperation = "source-over"
            ctx.clearRect(0, 0, width, rowH)
            for (let i = 0; i < root.newest.length; i++) {
                const x = Math.round(i * cellW)
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, Math.min(1, root.newest[i] / Viz.maxLevel) * root.peakAlpha)
                ctx.fillRect(x, 0, Math.round((i + 1) * cellW) - x, rowH)
            }
        }
    }
}
