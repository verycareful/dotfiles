// A row of mutually exclusive buttons; `value` is the selected one of `options`, `picked(v)` fires on a click.
import QtQuick
import ".."

Row {
    id: choice
    property var options: []
    property var labels: options      // shown text, one per option
    property string value
    signal picked(string v)
    spacing: 0

    Repeater {
        model: choice.options
        Rectangle {
            id: opt
            required property string modelData
            required property int index
            readonly property bool on: choice.value === modelData
            implicitWidth: label.implicitWidth + 22; implicitHeight: 26
            color: on ? Theme.accent : (hover.containsMouse ? Theme.glassCard : "transparent")
            border.width: 1; border.color: on ? Theme.accent : Theme.overlay
            Text {
                id: label
                anchors.centerIn: parent
                text: choice.labels[opt.index]
                color: opt.on ? Theme.textOnAccent : Theme.subtext
                font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
            }
            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: choice.picked(opt.modelData) }
        }
    }
}
