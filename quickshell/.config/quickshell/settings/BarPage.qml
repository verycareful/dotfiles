// Bar & music: whether the media controls sit on the bar.
import QtQuick
import QtQuick.Layouts
import "../panel"
import "../services"

ColumnLayout {
    spacing: 0
    SettingRow {
        first: true
        title: "Media on bar"
        detail: "The song title and playback buttons on the right of the bar."
        Widgets.Switch { on: Panel.mediaOnBar; onClicked: Panel.setMediaOnBar(!Panel.mediaOnBar) }
    }
}
