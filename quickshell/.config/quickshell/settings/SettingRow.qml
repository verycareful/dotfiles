// One setting: a title and a line of detail on the left, its control (the children) on the right,
// a hairline above every row but the first.
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: row
    property string title
    property string detail
    property bool first: false
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(text.implicitHeight, slot.childrenRect.height) + 22

    Rectangle { visible: !row.first; width: parent.width; height: 1; color: Theme.overlay }
    ColumnLayout {
        id: text
        anchors { left: parent.left; right: slot.left; rightMargin: 24; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text { text: row.title; color: Theme.text; font { family: Theme.fontUi; pixelSize: 13; weight: Font.DemiBold } }
        Text {
            visible: row.detail !== ""
            Layout.fillWidth: true
            text: row.detail; color: Theme.subtext; wrapMode: Text.WordWrap
            font { family: Theme.fontUi; pixelSize: 12 }
        }
    }
    Item {
        id: slot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: childrenRect.width; height: childrenRect.height
    }
}
