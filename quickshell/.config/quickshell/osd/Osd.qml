// On-screen display, bottom centre: volume and output mute, microphone mute, caps lock, brightness.
// Volume and the mutes follow PipeWire directly, so keys, the panel slider and pavucontrol all show it.
//   qs ipc call osd caps         (Caps Lock bind: reads the state from Hyprland)
//   qs ipc call osd brightness   (brightness binds: reads brightnessctl)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import ".."

Scope {
    id: root
    readonly property int hideAfter: 1400
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property bool shown: false
    property string glyph: ""
    property string label: ""
    property real level: -1      // 0..1 draws a bar; -1 hides it
    property bool warn: false    // muted / caps on: red accent
    property bool armed: false   // PipeWire reports every node's state at startup; ignore that burst

    function show(g, l, lv, w) {
        if (!armed) return
        glyph = g; label = l; level = lv; warn = w
        shown = true
        hide.restart()
    }
    function showVolume() {
        if (!sink || !sink.audio) return
        const v = sink.audio.volume, m = sink.audio.muted
        show(m ? "\u{F075F}" : (v < 0.34 ? "\u{F057F}" : (v < 0.67 ? "\u{F0580}" : "\u{F057E}")),
             m ? "Muted" : Math.round(v * 100) + "%", v, m)
    }
    function showMic() {
        if (!source || !source.audio) return
        const m = source.audio.muted
        show(m ? "\u{F036D}" : "\u{F036C}", m ? "Microphone off" : "Microphone on", -1, m)
    }

    PwObjectTracker { objects: [root.sink, root.source] }
    Connections { target: root.sink ? root.sink.audio : null; function onVolumeChanged() { root.showVolume() } function onMutedChanged() { root.showVolume() } }
    Connections { target: root.source ? root.source.audio : null; function onMutedChanged() { root.showMic() } }
    Timer { interval: 2000; running: true; onTriggered: root.armed = true }
    Timer { id: hide; interval: root.hideAfter; onTriggered: root.shown = false }

    Process {
        id: capsP
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main)
                    if (kb) root.show("\u{F0632}", kb.capsLock ? "Caps Lock on" : "Caps Lock off", -1, kb.capsLock)
                } catch (e) {}
            }
        }
    }
    Process {
        id: brightP
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt((text.split(",")[3] || "").replace("%", ""))
                if (!isNaN(pct)) root.show("\u{F00DF}", pct + "%", pct / 100, false)
            }
        }
    }
    IpcHandler {
        target: "osd"
        function caps(): void { capsP.running = true }
        function brightness(): void { brightP.running = true }
    }

    PanelWindow {
        visible: root.shown || card.opacity > 0
        anchors.bottom: true
        margins.bottom: 96
        implicitWidth: 320
        implicitHeight: 54
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-osd"
        mask: Region {}            // never takes a click

        Rectangle {
            id: card
            anchors.fill: parent
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            color: Theme.glassPanel
            border.width: 1; border.color: root.warn ? Theme.red : Theme.overlay
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                spacing: 14
                Text { text: root.glyph; color: root.warn ? Theme.red : Theme.accent; font { family: Theme.fontIcon; pixelSize: 24 } }
                Rectangle {
                    visible: root.level >= 0
                    Layout.fillWidth: true
                    implicitHeight: 6
                    color: Theme.overlay
                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, root.level)); height: parent.height
                        color: root.warn ? Theme.muted : Theme.accent
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }
                Text {
                    Layout.fillWidth: root.level < 0
                    horizontalAlignment: root.level < 0 ? Text.AlignLeft : Text.AlignRight
                    Layout.minimumWidth: root.level < 0 ? 0 : 52
                    text: root.label; color: Theme.text
                    font { family: Theme.fontUi; pixelSize: 14; weight: Font.Bold }
                }
            }
        }
    }
}
