// Small shared building blocks for the panel.
import QtQuick
import ".."

QtObject {
    // section title
    component Heading: Text {
        color: Theme.muted
        font { family: Theme.fontDisplay; pixelSize: 11; weight: Font.Bold; letterSpacing: 1.5 }
        text: ""
    }
    // flat glass tile
    component Tile: Rectangle {
        color: Theme.glassCard
        border.width: 1; border.color: Theme.overlay
    }
    // square icon toggle
    component Toggle: Rectangle {
        property string glyph
        property string label
        property bool on: false
        signal clicked
        signal secondary            // right click
        implicitWidth: 70; implicitHeight: 58
        color: on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55) : Theme.glassCard
        border.width: 1; border.color: on ? Theme.primaryBright : (tm.containsMouse ? Theme.muted : Theme.overlay)
        Column {
            anchors.centerIn: parent; spacing: 4
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.glyph; color: parent.parent.on ? Theme.accent : Theme.subtext; font { family: Theme.fontIcon; pixelSize: 20 } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.label; color: parent.parent.on ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 10; weight: Font.DemiBold } }
        }
        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => m.button === Qt.RightButton ? parent.secondary() : parent.clicked() }
    }
    // text button
    component Button: Rectangle {
        property string label
        property bool hot: false
        signal clicked
        implicitWidth: bl.implicitWidth + 18; implicitHeight: 26
        color: bm.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
        border.width: 1; border.color: bm.containsMouse ? (hot ? Theme.red : Theme.accent) : Theme.overlay
        Text { id: bl; anchors.centerIn: parent; text: parent.label; color: bm.containsMouse ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
