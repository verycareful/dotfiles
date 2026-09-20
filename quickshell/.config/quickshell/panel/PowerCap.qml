// GPU power cap: draw vs cap, slider over LACT's allowed range, presets (Quiet = min, Stock = default, Max).
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

ColumnLayout {
    id: pc
    spacing: 4
    property real pending: Gpu.cap
    property bool dragging: false
    readonly property real lo: Gpu.capMin
    readonly property real hi: Gpu.capMax
    readonly property real shown: dragging ? pending : Gpu.cap
    function frac(w) { return hi > lo ? (w - lo) / (hi - lo) : 0 }
    function apply(w) { if (Math.round(w) !== Math.round(Gpu.cap)) Gpu.setCap(w) }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text { text: Math.round(Gpu.power) + " W"; color: Theme.text; font { family: Theme.fontDisplay; pixelSize: 13; weight: Font.Bold } }
        Text { text: "draw"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
        Item { Layout.fillWidth: true }
        Text { text: (Gpu.busy ? "… " : "") + Math.round(pc.shown) + " W"; color: pc.dragging ? Theme.accent : Theme.subtext; font { family: Theme.fontDisplay; pixelSize: 12; weight: Font.Bold } }
        Text { text: "cap"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
    }
    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 16
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; color: Theme.overlay }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: pc.frac(Gpu.power) * parent.width; height: 3; color: Theme.primary }          // live draw
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: pc.frac(pc.shown) * parent.width; height: 3; color: pc.shown >= pc.hi ? Theme.red : Theme.primaryBright; opacity: 0.8 }
        Rectangle { x: pc.frac(Gpu.capDefault) * track.width - 1; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 9; color: Theme.muted }   // default mark
        Rectangle { x: pc.frac(pc.shown) * track.width - width / 2; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; color: Gpu.busy ? Theme.muted : Theme.accent; border.width: 1; border.color: Theme.base }
        MouseArea {
            anchors.fill: parent
            enabled: !Gpu.busy && pc.hi > pc.lo
            function at(x) { return Math.round(pc.lo + Math.max(0, Math.min(1, x / track.width)) * (pc.hi - pc.lo)) }
            onPressed: mouse => { pc.dragging = true; pc.pending = at(mouse.x) }
            onPositionChanged: mouse => { if (pressed) pc.pending = at(mouse.x) }
            onReleased: { pc.dragging = false; pc.apply(pc.pending) }
        }
    }
    RowLayout {
        spacing: 4
        Preset { label: "Quiet"; watts: Gpu.capMin }
        Preset { label: "Stock"; watts: Gpu.capDefault }
        Preset { label: "Max";   watts: Gpu.capMax }
        Item { Layout.fillWidth: true }
        Text { text: Math.round(pc.lo) + "–" + Math.round(pc.hi) + " W"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
    }
    component Preset: Rectangle {
        property string label
        property real watts
        readonly property bool active: Math.round(Gpu.cap) === Math.round(watts)
        implicitWidth: pl.implicitWidth + 14; implicitHeight: 20
        color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55) : (pm.containsMouse ? Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9) : "transparent")
        border.width: 1; border.color: active ? Theme.primaryBright : Theme.overlay
        Text { id: pl; anchors.centerIn: parent; text: parent.label + " " + Math.round(parent.watts); color: parent.active ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 10; weight: Font.DemiBold } }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; enabled: !Gpu.busy; onClicked: pc.apply(parent.watts) }
    }
}
