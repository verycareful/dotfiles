// Network state for the panel: links from `net status` (networkd + iwd), DNS settings from
// `dns-set status`. Refreshed every 3 s while the panel is open. DNS changes go through pkexec.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var eth: ({ dev: "", up: false, carrier: false })
    property var wifi: ({ dev: "", on: false, ssid: "" })
    property var dns: ({})              // { ethernet: {v4, v6, tls, name, device, live}, wifi: {...} }
    property string dnsBusy: ""         // the type being written
    property string dnsError: ""
    signal openDnsWindow()              // dns/DnsWindow.qml listens

    function refresh() { if (!links.running) links.running = true; if (!dnsStatus.running) dnsStatus.running = true }
    function setEthernet(on) { act.command = ["net", "ethernet", on ? "on" : "off"]; act.running = true }
    function setWifi(on)     { act.command = ["net", "wifi", on ? "on" : "off"]; act.running = true }
    // v4 / v6: "auto" or space-separated addresses ("" = none); ipv6 "on" | "off";
    // tls "yes" | "opportunistic" | "no"
    function setDns(type, v4, v6, ipv6, tls, name) {
        if (dnsBusy !== "") return
        dnsBusy = type; dnsError = ""
        setter.command = ["pkexec", "/usr/local/bin/dns-set", "set", type, "--v4", v4, "--v6", v6, "--ipv6", ipv6, "--tls", tls, "--name", name]
        setter.running = true
    }

    Process {
        id: links; command: ["net", "status"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.eth = j.ethernet; root.wifi = j.wifi } catch (e) {} } }
    }
    Process {
        id: dnsStatus; command: ["/usr/local/bin/dns-set", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.dns = JSON.parse(text) } catch (e) {} } }
    }
    Process { id: act; onExited: root.refresh() }
    Process {
        id: setter
        property string err: ""
        stderr: StdioCollector { onStreamFinished: setter.err = text.trim() }
        onExited: (code) => {
            root.dnsError = code === 0 ? "" : (code === 126 || code === 127) ? "cancelled" : (setter.err.split("\n").pop() || "failed")
            root.dnsBusy = ""
            root.refresh()
        }
    }
    Timer { interval: 3000; repeat: true; running: Panel.open; triggeredOnStart: true; onTriggered: root.refresh() }
}
