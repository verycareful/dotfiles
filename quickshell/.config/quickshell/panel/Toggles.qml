// Quick toggles: Wi-Fi · Bluetooth · DND · Night light · Power profile · Media on bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."
import "../services"

RowLayout {
    spacing: 6
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool perf: PowerProfiles.profile === PowerProfile.Performance

    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) || null
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F0200}"; label: "Ethernet";   on: wired ? wired.connected : false
                     onClicked: if (wired) Quickshell.execDetached(["nmcli", "device", wired.connected ? "disconnect" : "connect", wired.name]) }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F05A9}"; label: "Wi-Fi";      on: Networking.wifiEnabled;        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F00AF}"; label: "Bluetooth";  on: bt ? bt.enabled : false;       onClicked: if (bt) bt.enabled = !bt.enabled }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F009B}"; label: "Do not disturb"; on: Notifs.dnd;                onClicked: Notifs.setDnd(!Notifs.dnd) }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F0594}"; label: "Night light"; on: Panel.nightLight;             onClicked: Panel.setNightLight(!Panel.nightLight) }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F0E96}"; label: perf ? "Performance" : "Balanced"; on: perf
                     onClicked: PowerProfiles.profile = perf ? PowerProfile.Balanced : PowerProfile.Performance }
    Widgets.Toggle { Layout.fillWidth: true; glyph: "\u{F075A}"; label: "Media on bar"; on: Panel.mediaOnBar;            onClicked: Panel.setMediaOnBar(!Panel.mediaOnBar) }
}
