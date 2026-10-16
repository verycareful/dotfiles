// Permissions window. "By permission": the controlled ones (mic, screen sharing, clipboard) each with
// a global switch and an app list with Allow / Block, then the watched ones (camera, network, files,
// notifications, background apps), shown but never blocked. "By app": one app, everything about it.
// Data and changes go through services/Perms.qml (`perms status`, `perms set`, `perms switch`).
//   qs ipc call perms open|close|toggle   (also the Waybar shield)
//   qs ipc call perms tab app|perm        (open on that tab)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../panel"
import "../services"

Scope {
    id: root
    property string tab: "perm"         // perm | app
    property string expanded: ""        // the row whose app list is open
    property string selected: ""        // the app shown on the "By app" tab
    function show() { if (!win.backingWindowVisible) win.visible = false; win.visible = true }
    Connections { target: Perms; function onOpenWindow() { root.show() } }

    IpcHandler {
        target: "perms"
        function open(): void   { root.show() }
        function close(): void  { win.visible = false }
        function toggle(): void { if (win.backingWindowVisible) win.visible = false; else root.show() }
        function tab(name: string): void { root.tab = name === "app" ? "app" : "perm"; root.show() }
    }

    readonly property var s: Perms.status
    readonly property var controlled: [
        { key: "mic",       label: "Microphone",                     glyph: "\u{F036C}" },
        { key: "screen",    label: "Screen sharing and capture",     glyph: "\u{F0379}" },
        { key: "clipboard", label: "Clipboard, background reading",  glyph: "\u{F014C}" },
    ]
    readonly property var screenTools: ["grim", "hyprpicker"]
    readonly property int appListWidth: 180

    function keys(o) { return Object.keys(o || {}) }
    function clean(list) {
        const sys = Perms.system, out = []
        for (const a of list) if (a && a !== "?" && sys.indexOf(a) < 0 && out.indexOf(a) < 0) out.push(a)
        return out
    }
    function byLiveThenName(perm) {
        return (a, b) => {
            const la = !!(Perms.live[perm] || {})[a], lb = !!(Perms.live[perm] || {})[b]
            return la !== lb ? (la ? -1 : 1) : Perms.name(a).localeCompare(Perms.name(b))
        }
    }
    // apps worth listing under one permission: ruled, seen using it, or running now
    function candidates(perm) {
        const r = (Perms.rules[perm] || {}).apps
        let list = keys(r).concat(s.windows || [], s.background || [], keys(Perms.seen[perm]), keys(Perms.live[perm]))
        if (perm === "clipboard") list = list.concat(keys((s.clipboard || {}).apps))
        if (perm === "screen") list = list.concat(screenTools)
        return clean(list).sort(byLiveThenName(perm))
    }
    function allApps() {
        let list = keys(s.network).concat(keys((s.files || {}).history), keys((s.files || {}).open))
        for (const c of controlled) list = list.concat(candidates(c.key))
        list = list.concat(keys(Perms.seen.camera))
        return clean(list).sort((a, b) => Perms.name(a).localeCompare(Perms.name(b)))
    }
    function liveNames(perm) { const l = Perms.live[perm] || {}; return keys(l).map(k => l[k]).join(", ") }
    function blockedCount(perm) { return candidates(perm).filter(a => Perms.mode(perm, a) === "block").length }
    function lastUsed(perm, app) {
        if ((Perms.live[perm] || {})[app]) return "in use now"
        const e = (Perms.seen[perm] || {})[app]
        return e ? "last used " + Perms.ago(e.last) : ""
    }
    // what the clipboard rule means for this app right now
    function clipNote(app) {
        const st = ((s.clipboard || {}).apps || {})[app]
        const blocked = Perms.mode("clipboard", app) === "block"
        if (st === "x11") return { text: "X11 app: reads the clipboard freely, can't be restricted", warn: true }
        if (st === "restricted") return { text: blocked ? "restricted now" : "still restricted: restart it to lift", warn: !blocked }
        if (st === "open" && blocked) return { text: "running unrestricted: restart it to apply", warn: true }
        if (st === "open") return { text: "running, can read in the background", warn: false }
        return { text: "", warn: false }
    }
    function controlledSub(perm) {
        const r = Perms.rules[perm] || {}
        if (!r.on) return "Off for every app"
        const n = blockedCount(perm)
        let t = n === 0 ? "Allowed for every app" : n + (n === 1 ? " app blocked" : " apps blocked")
        if (perm === "screen") t += " · other capture tools get Hyprland's prompt"
        if (perm === "clipboard" && s.sandbox_installed === false) t = "Blocking needs perms-sandbox: sudo perms/install-perms.sh"
        return t
    }
    function fileTotal(folders) { let n = 0; for (const f in folders) n += folders[f][0]; return n }
    function fileApps() {
        const h = (s.files || {}).history || {}
        return clean(keys(h)).sort((a, b) => fileTotal(h[b]) - fileTotal(h[a]))
    }
    function topFolders(app, n) {
        const f = (((s.files || {}).history || {})[app]) || {}
        return keys(f).sort((a, b) => f[b][0] - f[a][0]).slice(0, n).map(k => k + " (" + f[k][0] + ")")
    }
    function sentFor(app) {
        const sent = Notifs.sent, want = [app, Perms.name(app)].map(x => String(x).toLowerCase())
        for (const k in sent) if (want.indexOf(k.toLowerCase()) >= 0) return sent[k]
        return null
    }

    FloatingWindow {
        id: win
        visible: false          // set, not bound: the compositor can close it too
        onClosed: visible = false
        onVisibleChanged: Perms.windowOpen = visible
        title: "Permissions"
        implicitWidth: 660
        implicitHeight: 760
        color: Theme.base

        ColumnLayout {
            anchors { fill: parent; margins: 18 }
            spacing: 14
            focus: true
            Keys.onEscapePressed: win.visible = false

            RowLayout {
                spacing: 0
                Layout.fillWidth: true
                Tab { type: "perm"; label: "By permission"; glyph: "\u{F099D}" }
                Tab { type: "app";  label: "By app";        glyph: "\u{F003B}" }
                Item { Layout.fillWidth: true }
                Text {
                    text: Perms.busy !== "" ? "Applying" : Perms.error
                    color: Perms.busy !== "" ? Theme.subtext : Theme.red
                    font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: root.tab === "perm" ? byPerm.implicitHeight : byApp.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // ── by permission ────────────────────────────────────
                ColumnLayout {
                    id: byPerm
                    visible: root.tab === "perm"
                    width: parent.width
                    spacing: 6

                    Section { text: "CONTROLLED"; sub: "can be blocked" }
                    Repeater {
                        model: root.controlled
                        delegate: ColumnLayout {
                            id: permItem
                            required property var modelData
                            readonly property string perm: modelData.key
                            Layout.fillWidth: true
                            spacing: 6
                            Row_ {
                                glyph: modelData.glyph; label: modelData.label
                                live: root.liveNames(modelData.key)
                                sub: root.controlledSub(modelData.key)
                                subWarn: modelData.key === "clipboard" && root.s.sandbox_installed === false
                                open: root.expanded === modelData.key
                                onToggleOpen: root.expanded = open ? "" : modelData.key
                                hasSwitch: true
                                switchOn: (Perms.rules[modelData.key] || {}).on !== false
                                switchBusy: Perms.busy === modelData.key + ":*"
                                onSwitched: Perms.setSwitch(modelData.key, !switchOn)
                            }
                            Sublist {
                                visible: root.expanded === modelData.key
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Note {
                                        visible: modelData.key === "clipboard" && ((root.s.clipboard || {}).managers || []).length > 0
                                        text: "Clipboard history: " + ((root.s.clipboard || {}).managers || []).join(", ") + " (reads everything, on purpose)"
                                    }
                                    Note {
                                        visible: (Perms.rules[modelData.key] || {}).on === false
                                        text: "The switch is off, so every app is blocked; the choices below apply once it is back on."
                                    }
                                    Repeater {
                                        model: root.candidates(modelData.key)
                                        delegate: AppLine {
                                            required property string modelData
                                            perm: permItem.perm
                                            app: modelData
                                        }
                                    }
                                    Note { visible: root.candidates(modelData.key).length === 0; text: "No apps yet." }
                                }
                            }
                        }
                    }

                    Section { text: "WATCHED"; sub: "shown, never blocked"; Layout.topMargin: 12 }

                    // camera
                    Row_ {
                        glyph: "\u{F0100}"; label: "Camera"
                        live: root.liveNames("camera")
                        sub: root.s.camera_present ? (root.keys(Perms.seen.camera).length + " apps have used it") : "No camera connected"
                        open: root.expanded === "camera"
                        onToggleOpen: root.expanded = open ? "" : "camera"
                    }
                    Sublist {
                        visible: root.expanded === "camera"
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Repeater {
                                model: root.clean(root.keys(Perms.seen.camera))
                                delegate: InfoLine { required property string modelData; app: modelData; info: root.lastUsed("camera", modelData) }
                            }
                            Note { visible: root.keys(Perms.seen.camera).length === 0; text: "Nothing has used a camera." }
                        }
                    }

                    // network
                    Row_ {
                        glyph: "\u{F059F}"; label: "Network"
                        sub: root.keys(root.s.network).length + " apps connected right now"
                        open: root.expanded === "network"
                        onToggleOpen: root.expanded = open ? "" : "network"
                    }
                    Sublist {
                        visible: root.expanded === "network"
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Repeater {
                                model: root.keys(root.s.network).sort((a, b) => root.s.network[b].connections - root.s.network[a].connections)
                                delegate: InfoLine {
                                    required property string modelData
                                    app: modelData
                                    info: root.s.network[modelData].connections + " connections to " + root.s.network[modelData].remotes + " hosts"
                                }
                            }
                        }
                    }

                    // files
                    Row_ {
                        glyph: "\u{F024B}"; label: "Files in your home folder"
                        sub: !(root.s.files || {}).watching ? "History needs the file watcher: sudo perms/install-perms.sh"
                           : root.fileApps().length + " apps opened files since " + Perms.ago((root.s.files || {}).since).replace(" ago", "") + " ago"
                        subWarn: !(root.s.files || {}).watching
                        open: root.expanded === "files"
                        onToggleOpen: root.expanded = open ? "" : "files"
                    }
                    Sublist {
                        visible: root.expanded === "files"
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Repeater {
                                model: root.fileApps()
                                delegate: InfoLine { required property string modelData; app: modelData; info: root.topFolders(modelData, 3).join(" · ") }
                            }
                            Heading_ { text: "OPEN RIGHT NOW" }
                            Repeater {
                                model: root.clean(root.keys((root.s.files || {}).open))
                                delegate: InfoLine { required property string modelData; app: modelData; info: ((root.s.files || {}).open[modelData] || []).join(" · ") }
                            }
                        }
                    }

                    // notifications
                    Row_ {
                        glyph: "\u{F009A}"; label: "Notifications"
                        sub: root.keys(Notifs.sent).length + " apps sent notifications this session"
                        open: root.expanded === "notifs"
                        onToggleOpen: root.expanded = open ? "" : "notifs"
                    }
                    Sublist {
                        visible: root.expanded === "notifs"
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Repeater {
                                model: root.keys(Notifs.sent).sort((a, b) => Notifs.sent[b].count - Notifs.sent[a].count)
                                delegate: InfoLine {
                                    required property string modelData
                                    app: modelData; display: modelData
                                    info: Notifs.sent[modelData].count + " · last " + Perms.ago(Notifs.sent[modelData].last)
                                }
                            }
                        }
                    }

                    // background
                    Row_ {
                        glyph: "\u{F0328}"; label: "Running in the background"
                        sub: (root.s.background || []).length + " apps running with no window"
                        open: root.expanded === "background"
                        onToggleOpen: root.expanded = open ? "" : "background"
                    }
                    Sublist {
                        visible: root.expanded === "background"
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Repeater {
                                model: root.s.background || []
                                delegate: InfoLine { required property string modelData; app: modelData; info: "no window" }
                            }
                        }
                    }
                }

                // ── by app ───────────────────────────────────────────
                RowLayout {
                    id: byApp
                    visible: root.tab === "app"
                    width: parent.width
                    spacing: 12

                    ColumnLayout {
                        // fixed width: the names would otherwise size the column and squeeze the details
                        Layout.fillWidth: false
                        Layout.preferredWidth: root.appListWidth
                        Layout.maximumWidth: root.appListWidth
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Repeater {
                            model: root.allApps()
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool on: root.selected === modelData
                                Layout.fillWidth: true
                                implicitHeight: 32
                                color: on ? Theme.glassCard : (am.containsMouse ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8) : "transparent")
                                border.width: 1; border.color: on ? Theme.primaryBright : Theme.overlay
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    Text {
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                        text: Perms.name(modelData)
                                        color: parent.parent.on ? Theme.text : Theme.subtext
                                        font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
                                    }
                                    Dot { visible: ["mic", "screen", "camera"].some(p => (Perms.live[p] || {})[modelData]) }
                                }
                                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: root.selected = modelData }
                            }
                        }
                    }

                    ColumnLayout {
                        id: appPane
                        Layout.fillWidth: true
                        Layout.preferredWidth: byApp.width - root.appListWidth - byApp.spacing
                        Layout.alignment: Qt.AlignTop
                        spacing: 6
                        readonly property string app: root.selected !== "" ? root.selected : (root.allApps()[0] || "")
                        Text {
                            text: Perms.name(appPane.app)
                            color: Theme.text
                            font { family: Theme.fontDisplay; pixelSize: 16; weight: Font.Bold }
                        }
                        Text {
                            visible: Perms.name(appPane.app) !== appPane.app
                            text: appPane.app; color: Theme.muted
                            font { family: Theme.fontUi; pixelSize: 11 }
                        }
                        Section { text: "CONTROLLED"; Layout.topMargin: 6 }
                        Repeater {
                            model: root.controlled
                            delegate: AppLine {
                                required property var modelData
                                perm: modelData.key
                                app: appPane.app
                                glyph: modelData.glyph
                                display: modelData.label
                            }
                        }
                        Section { text: "WATCHED"; Layout.topMargin: 10 }
                        InfoLine { glyph: "\u{F0100}"; display: "Camera"; info: root.lastUsed("camera", appPane.app) || "never used" }
                        InfoLine {
                            glyph: "\u{F059F}"; display: "Network"
                            readonly property var n: (root.s.network || {})[appPane.app]
                            info: n ? n.connections + " connections to " + n.remotes + " hosts now" : "no connections now"
                        }
                        InfoLine {
                            glyph: "\u{F024B}"; display: "Files"
                            info: !(root.s.files || {}).watching ? "file watcher not installed"
                                : (root.topFolders(appPane.app, 12).join("\n") || "nothing opened in your home folder")
                        }
                        InfoLine {
                            glyph: "\u{F024B}"; display: "Open now"
                            info: (((root.s.files || {}).open || {})[appPane.app] || []).join("\n") || "nothing"
                        }
                        InfoLine {
                            glyph: "\u{F009A}"; display: "Notifications"
                            readonly property var n: root.sentFor(appPane.app)
                            info: n ? n.count + " this session, last " + Perms.ago(n.last) : "none this session"
                        }
                        InfoLine {
                            glyph: "\u{F0328}"; display: "Background"
                            info: (root.s.background || []).indexOf(appPane.app) >= 0 ? "running with no window" : "no"
                        }
                    }
                }
            }
        }
    }

    // ── pieces ───────────────────────────────────────────────────
    component Tab: Rectangle {
        id: tabItem
        property string type
        property string label
        property string glyph
        readonly property bool active: root.tab === type
        implicitWidth: tr.implicitWidth + 28; implicitHeight: 36
        color: active ? Theme.glassCard : "transparent"
        border.width: 1; border.color: active ? Theme.primaryBright : Theme.overlay
        RowLayout {
            id: tr; anchors.centerIn: parent; spacing: 8
            Text { text: tabItem.glyph; color: tabItem.active ? Theme.accent : Theme.muted; font { family: Theme.fontIcon; pixelSize: 16 } }
            Text { text: tabItem.label; color: tabItem.active ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.Bold } }
        }
        MouseArea { anchors.fill: parent; onClicked: root.tab = tabItem.type }
    }

    component Section: RowLayout {
        property alias text: h.text
        property string sub
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8
        Widgets.Heading { id: h }
        Text { visible: parent.sub !== ""; text: parent.sub; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 10 } }
    }

    component Heading_: Widgets.Heading { Layout.topMargin: 8; Layout.bottomMargin: 2 }

    component Dot: Rectangle { implicitWidth: 7; implicitHeight: 7; radius: 3.5; color: Theme.green }

    // one permission: icon, name, live users, summary, "By app" toggle, optional global switch
    component Row_: Rectangle {
        id: row
        property string glyph
        property string label
        property string live: ""
        property string sub: ""
        property bool subWarn: false
        property bool open: false
        property bool hasSwitch: false
        property bool switchOn: true
        property bool switchBusy: false
        signal toggleOpen
        signal switched
        Layout.fillWidth: true
        implicitHeight: rr.implicitHeight + 20
        color: Theme.glassCard
        border.width: 1; border.color: open ? Theme.primaryBright : Theme.overlay
        RowLayout {
            id: rr
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
            spacing: 12
            Text { text: row.glyph; color: row.live !== "" ? Theme.green : Theme.accent; font { family: Theme.fontIcon; pixelSize: 20 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    spacing: 8
                    Text { text: row.label; color: Theme.text; font { family: Theme.fontUi; pixelSize: 13; weight: Font.Bold } }
                    Dot { visible: row.live !== "" }
                    Text { visible: row.live !== ""; text: row.live; color: Theme.green; elide: Text.ElideRight; Layout.fillWidth: true
                           font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold } }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: row.sub; color: row.subWarn ? Theme.yellow : Theme.subtext
                    font { family: Theme.fontUi; pixelSize: 11 }
                }
            }
            Rectangle {
                implicitWidth: br.implicitWidth + 16; implicitHeight: 26
                color: bm.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : "transparent"
                border.width: 1; border.color: bm.containsMouse || row.open ? Theme.primaryBright : Theme.overlay
                RowLayout {
                    id: br; anchors.centerIn: parent; spacing: 4
                    Text { text: "By app"; color: row.open ? Theme.text : Theme.subtext; font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold } }
                    Text { text: row.open ? "\u{F0143}" : "\u{F0140}"; color: Theme.subtext; font { family: Theme.fontIcon; pixelSize: 14 } }
                }
                MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; onClicked: row.toggleOpen() }
            }
            Widgets.Switch {
                visible: row.hasSwitch
                implicitWidth: 38; implicitHeight: 20
                on: row.switchOn
                locked: row.switchBusy || Perms.busy !== ""
                onClicked: row.switched()
            }
        }
    }

    // the indented list under an open row
    component Sublist: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        Layout.leftMargin: 34
        Layout.bottomMargin: 6
        implicitHeight: inner.implicitHeight + 8
        color: "transparent"
        Rectangle { width: 2; height: parent.height; color: Theme.primary }
        ColumnLayout { id: inner; anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; topMargin: 4 } }
    }

    component Note: Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        wrapMode: Text.Wrap
        color: Theme.muted
        font { family: Theme.fontUi; pixelSize: 11 }
    }

    // an app under a controlled permission, with Allow / Block
    component AppLine: Rectangle {
        id: line
        property string perm
        property string app
        property string glyph: ""
        property string display: Perms.name(app)
        readonly property string mode: Perms.mode(perm, app)
        readonly property bool busyHere: Perms.busy === perm + ":" + app
        readonly property var clip: perm === "clipboard" ? root.clipNote(app) : ({ text: "", warn: false })
        readonly property string info: [root.lastUsed(perm, app), clip.text].filter(x => x !== "").join(" · ")
        Layout.fillWidth: true
        implicitHeight: lr.implicitHeight + 12
        color: "transparent"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.surface }
        RowLayout {
            id: lr
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 10
            Text { visible: line.glyph !== ""; text: line.glyph; color: Theme.subtext; font { family: Theme.fontIcon; pixelSize: 15 } }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 1
                RowLayout {
                    spacing: 6
                    Text { text: line.display; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
                    Dot { visible: !!(Perms.live[line.perm] || {})[line.app] }
                }
                Text {
                    visible: line.info !== ""
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: line.info; color: line.clip.warn ? Theme.yellow : Theme.muted
                    font { family: Theme.fontUi; pixelSize: 10 }
                }
            }
            Text { visible: line.busyHere; text: "applying"; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 10 } }
            RowLayout {
                spacing: 0
                Choice { label: "Allow"; active: line.mode === "allow"; onClicked: Perms.setApp(line.perm, line.app, "allow") }
                Choice { label: "Block"; active: line.mode === "block"; danger: true; onClicked: Perms.setApp(line.perm, line.app, "block") }
            }
        }
    }

    // an app (or a category) with a line of facts, no controls
    component InfoLine: Rectangle {
        id: il
        property string app: ""
        property string glyph: ""
        property string display: Perms.name(app)
        property string info: ""
        Layout.fillWidth: true
        implicitHeight: ir.implicitHeight + 12
        color: "transparent"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.surface }
        RowLayout {
            id: ir
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 10
            Text { visible: il.glyph !== ""; text: il.glyph; color: Theme.subtext; Layout.alignment: Qt.AlignTop; font { family: Theme.fontIcon; pixelSize: 15 } }
            Text { text: il.display; color: Theme.text; Layout.preferredWidth: 120; Layout.maximumWidth: 120; Layout.alignment: Qt.AlignTop
                   elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
            Text { text: il.info; color: Theme.subtext; Layout.fillWidth: true; Layout.preferredWidth: 1; wrapMode: Text.WordWrap
                   font { family: Theme.fontUi; pixelSize: 11 } }
        }
    }

    component Choice: Rectangle {
        property string label
        property bool active: false
        property bool danger: false
        signal clicked
        implicitWidth: cl.implicitWidth + 18; implicitHeight: 24
        opacity: Perms.busy !== "" ? 0.5 : 1
        color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55) : (cm.containsMouse ? Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9) : "transparent")
        border.width: 1; border.color: active ? (danger ? Theme.red : Theme.primaryBright) : Theme.overlay
        Text { id: cl; anchors.centerIn: parent; text: parent.label; color: parent.active ? (parent.danger ? Theme.red : Theme.text) : Theme.subtext
               font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold } }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; enabled: Perms.busy === "" && !parent.active; onClicked: parent.clicked() }
    }
}
