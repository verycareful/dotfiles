// Month calendar, today highlighted, ‹ › browse.
import QtQuick
import QtQuick.Layouts
import ".."

Widgets.Tile {
    id: cal
    implicitHeight: col.implicitHeight + 16
    property date shown: new Date()
    readonly property date today: new Date()
    readonly property int year: shown.getFullYear()
    readonly property int month: shown.getMonth()
    readonly property int first: (new Date(year, month, 1).getDay() + 6) % 7     // Monday = 0
    readonly property int days: new Date(year, month + 1, 0).getDate()

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Widgets.Button { label: "\u{F0141}"; onClicked: cal.shown = new Date(cal.year, cal.month - 1, 1) }   // chevron-left
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(cal.shown, "MMMM yyyy"); color: Theme.text; font { family: Theme.fontDisplay; pixelSize: 13; weight: Font.Bold } }
            Widgets.Button { label: "\u{F0142}"; onClicked: cal.shown = new Date(cal.year, cal.month + 1, 1) }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 7; rowSpacing: 2; columnSpacing: 2
            Repeater { model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]; Text { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10; weight: Font.Bold } } }
            Repeater {
                model: cal.first + cal.days
                Rectangle {
                    required property int index
                    readonly property int day: index - cal.first + 1
                    readonly property bool isToday: day === cal.today.getDate() && cal.month === cal.today.getMonth() && cal.year === cal.today.getFullYear()
                    Layout.fillWidth: true
                    implicitHeight: 22
                    color: isToday ? Theme.accent : "transparent"
                    Text { anchors.centerIn: parent; visible: parent.day >= 1; text: parent.day; color: parent.isToday ? Theme.base : ((index % 7) >= 5 ? Theme.subtext : Theme.text); font { family: Theme.fontUi; pixelSize: 11; weight: parent.isToday ? Font.Bold : Font.Normal } }
                }
            }
        }
    }
}
