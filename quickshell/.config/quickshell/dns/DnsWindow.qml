// DNS settings window: one tab for Ethernet, one for Wi-Fi (every Wi-Fi network). Per tab, like a
// connection editor: IPv4 and IPv6 servers each Automatic (the network's, i.e. the ISP's) or
// entered, plus the DNS-over-TLS server name. Apply runs `pkexec dns-set set …`.
//   qs ipc call dns open|close|toggle   (also the panel's DNS card)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../panel"
import "../services"

Scope {
    id: root
    property string tab: "ethernet"
    // Closing it from Hyprland (SUPER+Q) destroys the real window but leaves `visible` true, so a
    // plain `visible = true` would do nothing: recreate it whenever nothing is on screen.
    function show() { if (!win.backingWindowVisible) win.visible = false; win.visible = true }
    Connections { target: Net; function onOpenDnsWindow() { root.show() } }

    IpcHandler {
        target: "dns"
        function open(): void   { root.show() }
        function close(): void  { win.visible = false }
        function toggle(): void { if (win.backingWindowVisible) win.visible = false; else root.show() }
    }

    FloatingWindow {
        id: win
        visible: false          // set, not bound: the compositor can close it too
        onClosed: visible = false
        title: "DNS settings"
        implicitWidth: 540
        implicitHeight: body.implicitHeight + 36
        color: Theme.base
        // show what is installed; reload once more when the fresh status arrives
        onVisibleChanged: if (visible) { eth.load(); wifi.load(); eth.reloadOnce = wifi.reloadOnce = true; Net.refresh() }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 14
            focus: true
            Keys.onEscapePressed: win.visible = false

            RowLayout {
                spacing: 0
                Tab { type: "ethernet"; label: "Ethernet"; glyph: "\u{F0200}"; sub: Net.eth.dev }
                Tab { type: "wifi";     label: "Wi-Fi";    glyph: "\u{F05A9}"; sub: Net.wifi.ssid !== "" ? Net.wifi.ssid : Net.wifi.dev }
                Item { Layout.fillWidth: true }
            }
            Form { id: eth;  type: "ethernet"; visible: root.tab === "ethernet" }
            Form { id: wifi; type: "wifi";     visible: root.tab === "wifi" }
            RowLayout {
                Text { text: Net.dnsError; color: Theme.red; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: 11 } }
                Widgets.Button { label: "Revert"; onClicked: (root.tab === "ethernet" ? eth : wifi).load() }
                Widgets.Button { label: Net.dnsBusy !== "" ? "Applying…" : "Apply"; hot: true; onClicked: (root.tab === "ethernet" ? eth : wifi).apply() }
            }
        }
    }

    component Tab: Rectangle {
        id: tabItem
        property string type
        property string label
        property string glyph
        property string sub
        readonly property bool active: root.tab === type
        implicitWidth: tr.implicitWidth + 28; implicitHeight: 36
        color: active ? Theme.glassCard : "transparent"
        border.width: 1; border.color: active ? Theme.primaryBright : Theme.overlay
        RowLayout {
            id: tr; anchors.centerIn: parent; spacing: 8
            Text { text: tabItem.glyph; color: tabItem.active ? Theme.accent : Theme.muted; font { family: Theme.fontIcon; pixelSize: 16 } }
            Text { text: tabItem.label; color: tabItem.active ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.Bold } }
            Text { text: tabItem.sub; visible: text !== ""; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
        }
        MouseArea { anchors.fill: parent; onClicked: root.tab = tabItem.type }
    }

    // one tab's settings; load() copies the installed setting in, apply() writes the fields
    component Form: ColumnLayout {
        id: form
        property string type
        readonly property var cfg: Net.dns[type] || ({ v4: "auto", v6: "auto", ipv6: "on", tls: "no", name: "", live: "" })
        property string tls: "no"
        property bool reloadOnce: false
        Layout.fillWidth: true
        spacing: 12

        function load() {
            const c = cfg
            v4.auto = c.v4 === "auto"; v6.auto = c.v6 === "auto"; v6.on = c.ipv6 !== "off"
            const a4 = v4.auto ? [] : c.v4.split(" "), a6 = v6.auto ? [] : c.v6.split(" ")
            v4.first = a4[0] || ""; v4.second = a4[1] || ""
            v6.first = a6[0] || ""; v6.second = a6[1] || ""
            name.text = c.name; tls = c.tls !== "" ? c.tls : "no"
        }
        function apply() { Net.setDns(type, v4.value(), v6.value(), v6.on ? "on" : "off", tls, name.text.trim()) }
        onCfgChanged: if (reloadOnce) { reloadOnce = false; load() }

        Text {
            Layout.fillWidth: true
            text: "In use now: " + (form.cfg.live !== "" ? form.cfg.live : "none")
            color: Theme.subtext; wrapMode: Text.WrapAnywhere; font { family: Theme.fontUi; pixelSize: 10 }
        }
        Family { id: v4; title: "IPv4" }
        Family { id: v6; title: "IPv6"; canDisable: true }

        Widgets.Heading { text: "ENCRYPTED DNS (DNS-OVER-TLS)"; Layout.topMargin: 4 }
        Field { id: name; Layout.fillWidth: true; placeholder: "server name, e.g. tls://39997d19.d.adguard-dns.com (empty: none)" }
        RowLayout {
            spacing: 4
            Chip { label: "Strict";     active: form.tls === "yes";           onClicked: form.tls = "yes" }
            Chip { label: "If offered"; active: form.tls === "opportunistic"; onClicked: form.tls = "opportunistic" }
            Chip { label: "Off";        active: form.tls === "no";            onClicked: form.tls = "no" }
            Text {
                Layout.leftMargin: 8; Layout.fillWidth: true; wrapMode: Text.Wrap
                text: form.tls === "yes" ? "Only encrypted; lookups fail if the servers can't do TLS"
                    : form.tls === "opportunistic" ? "Encrypted when the servers support it, plain otherwise" : "Plain DNS"
                color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 }
            }
        }
        Text {
            readonly property string warn:
                form.tls === "yes" && (v4.auto || (v6.on && v6.auto)) ? "Strict TLS with Automatic: the network's own servers don't speak TLS and will fail. Enter the addresses, or leave a family empty to use none."
              : form.tls === "yes" && name.text.trim() === "" ? "Strict TLS needs the server name (the one its certificate is for)."
              : !v4.auto && (!v6.on || !v6.auto) && v4.value() === "" && v6.value() === "" ? "No servers at all: nothing will resolve on this connection."
              : ""
            visible: warn !== ""; text: warn
            Layout.fillWidth: true; wrapMode: Text.Wrap
            color: Theme.yellow; font { family: Theme.fontUi; pixelSize: 11 }
        }
    }

    // one address family: Automatic switch + two server fields
    component Family: ColumnLayout {
        id: fam
        property string title
        property bool canDisable: false     // IPv6: switch the whole family off on this link
        property bool on: true
        property bool auto: true
        property alias first: f1.text
        property alias second: f2.text
        function value() { return !on ? "" : auto ? "auto" : [f1.text.trim(), f2.text.trim()].filter(s => s !== "").join(" ") }
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Widgets.Heading { text: fam.title; Layout.fillWidth: true }
            Text { visible: fam.canDisable; text: "Enabled"; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 11 } }
            Switch { visible: fam.canDisable; on: fam.on; onToggled: fam.on = !fam.on }
            Text { visible: fam.on; Layout.leftMargin: 10; text: "Automatic"; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 11 } }
            Switch { visible: fam.on; on: fam.auto; onToggled: fam.auto = !fam.auto }
        }
        Text {
            visible: !fam.on; Layout.fillWidth: true
            text: "IPv6 is off on this connection: no address, no IPv6 DNS"
            color: Theme.muted; font { family: Theme.fontUi; pixelSize: 11 }
        }
        RowLayout {
            visible: fam.on
            spacing: 8
            Field { id: f1; Layout.fillWidth: true; enabled: !fam.auto; placeholder: fam.auto ? "from the network" : "DNS server 1" }
            Field { id: f2; Layout.fillWidth: true; enabled: !fam.auto; placeholder: fam.auto ? "" : "DNS server 2 (optional)" }
        }
    }

    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder
        implicitHeight: 28
        opacity: enabled ? 1 : 0.4
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
        border.width: 1; border.color: input.activeFocus ? Theme.accent : Theme.overlay
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text; clip: true; selectByMouse: true
            font { family: Theme.fontUi; pixelSize: 12 }
            Text { visible: input.text === "" && !input.activeFocus; anchors.verticalCenter: parent.verticalCenter; text: field.placeholder; color: Theme.muted; font: input.font }
        }
    }

    component Switch: Rectangle {
        property bool on
        signal toggled
        implicitWidth: 34; implicitHeight: 18
        color: on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.7) : Theme.surface
        border.width: 1; border.color: on ? Theme.primaryBright : Theme.overlay
        Rectangle { width: 12; height: 12; y: 3; x: parent.on ? parent.width - width - 3 : 3; color: parent.on ? Theme.accent : Theme.muted
                    Behavior on x { NumberAnimation { duration: 120 } } }
        MouseArea { anchors.fill: parent; onClicked: parent.toggled() }
    }

    component Chip: Rectangle {
        property string label
        property bool active: false
        signal clicked
        implicitWidth: cl.implicitWidth + 16; implicitHeight: 24
        color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55) : (cm.containsMouse ? Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9) : "transparent")
        border.width: 1; border.color: active ? Theme.primaryBright : Theme.overlay
        Text { id: cl; anchors.centerIn: parent; text: parent.label; color: parent.active ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold } }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
