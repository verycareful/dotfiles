// Quick toggles: Wi-Fi · Bluetooth · DND · Night light · Power profile · Media on bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."
import "../services"

Flow {
    spacing: 8
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool perf: PowerProfiles.profile === PowerProfile.Performance

    Widgets.Toggle { glyph: "\u{F05A9}"; label: "Wi-Fi";      on: Networking.wifiEnabled;        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled }
    Widgets.Toggle { glyph: "\u{F00AF}"; label: "Bluetooth";  on: bt ? bt.enabled : false;       onClicked: if (bt) bt.enabled = !bt.enabled }
    Widgets.Toggle { glyph: "\u{F009B}"; label: "Do not disturb"; on: Notifs.dnd;                onClicked: Notifs.setDnd(!Notifs.dnd) }
    Widgets.Toggle { glyph: "\u{F0594}"; label: "Night light"; on: Panel.nightLight;             onClicked: Panel.setNightLight(!Panel.nightLight) }
    Widgets.Toggle { glyph: "\u{F0E96}"; label: perf ? "Performance" : "Balanced"; on: perf
                     onClicked: PowerProfiles.profile = perf ? PowerProfile.Balanced : PowerProfile.Performance }
    Widgets.Toggle { glyph: "\u{F075A}"; label: "Media on bar"; on: Panel.mediaOnBar;            onClicked: Panel.setMediaOnBar(!Panel.mediaOnBar) }
}
