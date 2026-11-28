// Bar & music: whether the media controls sit on the bar, and the song visualiser's look and layout.
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
    SettingRow {
        title: "Visualiser look"
        detail: "How the song shows on the Music screen and the Now playing card. Left and Right on the Music screen change it too."
        Choice {
            options: Panel.vizStyles
            labels: ["Bars", "Waveform", "Radial", "Waterfall"]
            value: Panel.vizStyle
            onPicked: v => Panel.setVizStyle(v)
        }
    }
    SettingRow {
        title: "Spectrum layout"
        detail: "Mono runs from the lowest frequency on the left to the highest on the right. Stereo mirrors it about the middle, the lowest frequencies in the centre. The waveform look is not affected."
        Choice {
            options: Panel.vizLayouts
            labels: ["Mono", "Stereo"]
            value: Panel.vizLayout
            onPicked: v => Panel.setVizLayout(v)
        }
    }
}
