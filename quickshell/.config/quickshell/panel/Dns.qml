// DNS summary: what each connection resolves through right now. "DNS settings" opens the window
// (dns/DnsWindow.qml) where Ethernet and Wi-Fi each get their own servers.
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Widgets.Tile {
    id: tile
    implicitHeight: col.implicitHeight + 20

    RowLayout {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 12 }
        spacing: 10
        ColumnLayout {
            id: col
            Layout.fillWidth: true
            spacing: 4
            Line { type: "ethernet"; glyph: "\u{F0200}" }
            Line { type: "wifi";     glyph: "\u{F05A9}" }
        }
        Widgets.Button { label: "DNS settings"; Layout.alignment: Qt.AlignVCenter; onClicked: { Net.openDnsWindow(); Panel.setOpen(false) } }
    }

    component Line: RowLayout {
        id: line
        property string type
        property string glyph
        readonly property var cfg: Net.dns[type] || ({ v4: "", v6: "", ipv6: "on", tls: "", live: "" })
        readonly property bool manual: cfg.v4 !== "auto" || (cfg.ipv6 !== "off" && cfg.v6 !== "auto")
        Layout.fillWidth: true
        spacing: 8
        Text { text: line.glyph; color: line.manual ? Theme.accent : Theme.muted; font { family: Theme.fontIcon; pixelSize: 14 } }
        Text {
            text: (line.manual ? "" : "Automatic  ") + (line.cfg.ipv6 === "off" ? "no IPv6  " : "") + (line.cfg.tls === "yes" ? "󰌾 " : "")
            visible: text !== ""; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 10; weight: Font.DemiBold }
        }
        Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            text: line.cfg.live !== "" ? line.cfg.live.split(" ").map(s => s.split("#")[0]).join("  ") : "no DNS in use"
            color: line.cfg.live !== "" ? Theme.text : Theme.muted; font { family: Theme.fontUi; pixelSize: 11 }
        }
    }
}
