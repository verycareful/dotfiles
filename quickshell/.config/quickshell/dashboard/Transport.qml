// Previous, play or pause, next for `player` (an MPRIS player, or null), centred on one line.
import QtQuick
import QtQuick.Layouts

RowLayout {
    property var player
    spacing: 6
    MBtn { glyph: "\u{F04AE}"; enabled: player && player.canGoPrevious; onClicked: player.previous() }
    MBtn { glyph: player && player.isPlaying ? "\u{F03E4}" : "\u{F040A}"; big: true; onClicked: player.togglePlaying() }
    MBtn { glyph: "\u{F04AD}"; enabled: player && player.canGoNext; onClicked: player.next() }
}
