// An icon from the icon font, centred at a common size in a `size` x `size` box.
// Icon-font glyphs differ in how much of their cell they fill and where they sit in it, so a plain Text
// centres the cell, not the shape, and two icons of one pixel size look different sizes. Glyph measures
// the shape (TextMetrics' tight bounding rect at a reference size), scales it so its larger side is `ink`
// px, and puts the shape's centre on the box's centre.
import QtQuick

Item {
    id: g
    property string text
    property color color: Theme.text
    property int size: 20                       // the square box, in px
    property real ink: size * inkRatio          // the shape's larger side, in px
    readonly property real inkRatio: 0.85
    readonly property int refPx: 200            // measuring size: large, so rounding stays small
    implicitWidth: size
    implicitHeight: size

    TextMetrics { id: m; font.family: Theme.fontIcon; font.pixelSize: g.refPx; text: g.text }
    readonly property rect shape: m.tightBoundingRect                   // at refPx, relative to the baseline origin
    readonly property real big: Math.max(shape.width, shape.height)
    readonly property int px: Math.max(1, Math.round(big > 0 ? g.refPx * g.ink / big : g.size))
    readonly property real k: px / refPx                                // the drawn scale, after rounding

    Text {
        text: g.text
        color: g.color
        font.family: Theme.fontIcon
        font.pixelSize: g.px
        x: g.width / 2 - (g.shape.x + g.shape.width / 2) * g.k
        y: g.height / 2 - baselineOffset - (g.shape.y + g.shape.height / 2) * g.k
    }
}
