// Network & DNS: the links on and off, the Wi-Fi picker, Bluetooth, and what each connection resolves through.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../panel"
import "../services"

ColumnLayout {
    spacing: 14
    readonly property var bt: Bluetooth.defaultAdapter

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        SettingRow {
            first: true
            title: "Ethernet"; detail: Net.eth.dev !== "" ? Net.eth.dev + (Net.eth.carrier ? " · cable in" : " · no cable") : "No wired device"
            Widgets.Switch { on: Net.eth.up; onClicked: Net.setEthernet(!Net.eth.up) }
        }
        SettingRow {
            title: "Wi-Fi"; detail: Net.wifi.on ? (Net.wifi.ssid !== "" ? "Connected to " + Net.wifi.ssid : "On, not connected") : "Off"
            Row {
                spacing: 10
                Widgets.Button { label: "Networks…"; onClicked: Panel.runPicker([Quickshell.env("HOME") + "/.local/bin/wifi"], "network") }
                Widgets.Switch { anchors.verticalCenter: parent.verticalCenter; on: Net.wifi.on; onClicked: Net.setWifi(!Net.wifi.on) }
            }
        }
        SettingRow {
            title: "Bluetooth"; detail: bt ? (bt.enabled ? "On" : "Off") : "No adapter"
            Widgets.Switch { locked: !bt; on: bt ? bt.enabled : false; onClicked: if (bt) bt.enabled = !bt.enabled }
        }
    }
    Dns { Layout.fillWidth: true }
}
