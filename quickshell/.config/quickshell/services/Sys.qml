// System + ClamAV numbers for the panel, polled only while it is open.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var sys: ({ cpu: 0, tctl: 0, memUsed: 0, memTotal: 0, gpu: 0, gpuTemp: 0, vramUsed: 0, vramTotal: 0, uptime: "", updates: "" })
    property var clam: ({ block: "", notify: "", daemon: "", found: 0, lastScan: "", lastInfected: "", log: "", sigs: "" })

    Process { id: sysP;  command: ["panel-sys"];  stdout: StdioCollector { onStreamFinished: { try { root.sys  = JSON.parse(text) } catch (e) {} } } }
    Process { id: clamP; command: ["panel-clam"]; stdout: StdioCollector { onStreamFinished: { try { root.clam = JSON.parse(text) } catch (e) {} } } }
    Timer { interval: 3000;  running: Panel.open; repeat: true; triggeredOnStart: true; onTriggered: sysP.running = true }
    Timer { interval: 15000; running: Panel.open; repeat: true; triggeredOnStart: true; onTriggered: clamP.running = true }
}
