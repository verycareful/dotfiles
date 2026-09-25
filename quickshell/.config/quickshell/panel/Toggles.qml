// Quick toggles (right-click Wi-Fi for the network picker): Wi-Fi · Bluetooth · DND · Night light · Power profile · Media on bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."
import "../services"

RowLayout {
    spacing: 6
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool perf: PowerProfiles.profile === PowerProfile.Performance

    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F0200}"; label: "Ethernet";   on: Net.eth.up;                    onClicked: Net.setEthernet(!Net.eth.up) }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F05A9}"; label: "Wi-Fi";      on: Net.wifi.on;                   onClicked: Net.setWifi(!Net.wifi.on)
                     onSecondary: { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wifi"]); Panel.setOpen(false) } }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F00AF}"; label: "Bluetooth";  on: bt ? bt.enabled : false;       onClicked: if (bt) bt.enabled = !bt.enabled }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F009B}"; label: "Do not disturb"; on: Notifs.dnd;                onClicked: Notifs.setDnd(!Notifs.dnd) }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F0594}"; label: "Night light"; on: Panel.nightLight;             onClicked: Panel.setNightLight(!Panel.nightLight) }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F0E96}"; label: perf ? "Performance" : "Balanced"; on: perf
                     onClicked: PowerProfiles.profile = perf ? PowerProfile.Balanced : PowerProfile.Performance }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F075A}"; label: "Media on bar"; on: Panel.mediaOnBar;            onClicked: Panel.setMediaOnBar(!Panel.mediaOnBar) }
}
