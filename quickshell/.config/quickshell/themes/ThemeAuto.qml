// Runs `theme auto tick` at start and every few minutes: while `theme auto` is on, the light half of the
// theme pair shows from sunrise to sunset and the dark half otherwise. The tick does nothing when auto is
// off or the right half already shows. Detached, because a switch re-renders Theme.qml and reloads the shell.
import QtQuick
import Quickshell

Item {
    id: root
    readonly property int tickMs: 5 * 60 * 1000

    Timer {
        interval: root.tickMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/theme", "auto", "tick"])
    }
}
