// A media button: a glyph on a square that lights on hover; `big` is the larger play and pause one.
import QtQuick
import ".."

Rectangle {
    property string glyph
    property bool big: false
    signal clicked
    implicitWidth: big ? 48 : 38; implicitHeight: big ? 48 : 38
    color: mm.containsMouse && enabled ? Theme.fillHover : "transparent"
    border.width: big ? 1 : 0; border.color: Theme.overlay
    Glyph { anchors.centerIn: parent; text: parent.glyph; color: parent.enabled ? (mm.containsMouse ? Theme.accent : Theme.text) : Theme.muted; size: parent.big ? 26 : 20 }
    MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: if (parent.enabled) parent.clicked() }
}
