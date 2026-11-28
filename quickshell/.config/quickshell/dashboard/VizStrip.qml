// A small live strip on the Now playing card, in the look chosen in Settings (radial is a ring, which does not fit
// a strip, so it shows as bars). `shown` says whether the card is on screen; the strip holds services/Viz.qml
// (and so its audio source) only while it is.
import QtQuick
import ".."
import "../services"
import "../viz"

Item {
    id: root
    property bool shown: false
    onShownChanged: Viz.hold("nowplaying", shown)
    Component.onCompleted: Viz.hold("nowplaying", shown)
    Component.onDestruction: Viz.hold("nowplaying", false)

    Look {
        anchors.fill: parent
        style: Panel.vizStyle === "radial" ? "bars" : Panel.vizStyle
        compact: true
    }
}
