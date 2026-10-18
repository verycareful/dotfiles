// One Safeguards row: icon, title and detail, then whatever buttons or switches are declared inside it.
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: r
    property string glyph
    property color tint: Theme.subtext
    property string title
    property string detail
    default property alias actions: box.data
    Layout.fillWidth: true
    spacing: 12
    Text { text: r.glyph; color: r.tint; font { family: Theme.fontIcon; pixelSize: 24 } }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text { text: r.title; color: Theme.text; font { family: Theme.fontUi; pixelSize: 13; weight: Font.Bold } }
        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: r.detail; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 11 } }
    }
    RowLayout { id: box; spacing: 4 }
}
