// Bar & visualiser: the song visualiser's mode and whether the media controls sit on the bar.
import QtQuick
import QtQuick.Layouts
import "../panel"
import "../services"

ColumnLayout {
    spacing: 0
    SettingRow {
        first: true
        title: "Song visualiser"
        detail: "Compact sits beside the song, wide fills the centre of the bar, full runs under the whole bar. SUPER+Shift+V cycles."
        Choice {
            options: Panel.vizModes
            labels: ["Off", "Compact", "Wide", "Full"]
            value: Panel.vizMode
            onPicked: v => Panel.setVizMode(v)
        }
    }
    SettingRow {
        title: "Media on bar"
        detail: "The song title and playback buttons on the right of the bar."
        Widgets.Switch { on: Panel.mediaOnBar; onClicked: Panel.setMediaOnBar(!Panel.mediaOnBar) }
    }
}
