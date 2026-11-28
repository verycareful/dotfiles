// One of the four looks, by name: bars, waveform, radial or waterfall. Each fills this item and draws from
// services/Viz.qml; `compact` asks for the small version (the Now playing strip), `art` is the radial look's centre.
import QtQuick

Item {
    id: root
    property string style: "bars"
    property bool compact: false
    property url art

    readonly property var sources: ({ bars: "BarsLook.qml", waveform: "WaveLook.qml", radial: "RadialLook.qml", waterfall: "WaterfallLook.qml" })

    Loader { id: loader; anchors.fill: parent; source: root.sources[root.style] || root.sources.bars }
    Binding { target: loader.item; property: "compact"; value: root.compact }
    Binding { target: loader.item; property: "art"; value: root.art; when: loader.item !== null && loader.item.art !== undefined }
}
